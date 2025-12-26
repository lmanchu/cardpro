import Foundation
import CloudKit
import SwiftUI

/// Sync status for iCloud
enum SyncStatus: Equatable {
    case disabled
    case syncing
    case synced(lastSync: Date)
    case error(String)

    var displayText: String {
        switch self {
        case .disabled:
            return L10n.Sync.disabled
        case .syncing:
            return L10n.Sync.syncing
        case .synced(let date):
            return L10n.Sync.lastSync(date.relativeString)
        case .error(let message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .disabled:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .disabled:
            return .secondary
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        }
    }
}

/// Service to monitor iCloud sync status
@MainActor
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published private(set) var syncStatus: SyncStatus = .disabled
    @Published private(set) var isCloudKitAvailable = false

    private init() {
        checkCloudKitAvailability()
        setupNotifications()
    }

    // MARK: - CloudKit Availability

    func checkCloudKitAvailability() {
        CKContainer(identifier: "iCloud.com.lman.cardpro").accountStatus { [weak self] status, error in
            Task { @MainActor in
                switch status {
                case .available:
                    self?.isCloudKitAvailable = true
                    self?.syncStatus = .synced(lastSync: Date())
                case .noAccount:
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error(L10n.Sync.noAccount)
                case .restricted:
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error(L10n.Sync.restricted)
                case .couldNotDetermine:
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error(L10n.Sync.unknown)
                case .temporarilyUnavailable:
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error(L10n.Sync.temporarilyUnavailable)
                @unknown default:
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .disabled
                }
            }
        }
    }

    // MARK: - Sync Status Updates

    private func setupNotifications() {
        // Listen for CloudKit notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChange),
            name: .CKAccountChanged,
            object: nil
        )
    }

    @objc private func handleAccountChange() {
        checkCloudKitAvailability()
    }

    /// Manually trigger a sync status refresh
    func refreshSyncStatus() {
        syncStatus = .syncing
        checkCloudKitAvailability()
    }
}

// MARK: - Date Extension

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
