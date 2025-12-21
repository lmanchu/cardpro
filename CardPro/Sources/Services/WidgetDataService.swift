import Foundation
import WidgetKit

/// Service for sharing card data with the widget
class WidgetDataService {
    static let shared = WidgetDataService()

    private let userDefaultsKey = "SharedCardData"
    private let suiteName = "group.com.lman.cardpro"

    private init() {}

    /// Update widget with the default card data
    func updateWidget(with card: BusinessCard) {
        let sharedData = SharedCardData(
            name: card.displayName,
            localizedName: card.localizedFullName,
            title: card.title,
            company: card.company,
            vcardString: QRCodeGenerator.shared.generateCompactVCard(from: card)
        )

        saveSharedData(sharedData)

        // Tell WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Clear widget data
    func clearWidget() {
        // Try App Groups
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            sharedDefaults.removeObject(forKey: userDefaultsKey)
        }
        // Also clear standard
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveSharedData(_ data: SharedCardData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }

        // Try App Groups first (requires paid account)
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            sharedDefaults.set(encoded, forKey: userDefaultsKey)
        }
        // Also save to standard UserDefaults (fallback for development)
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }
}

/// Shared card data structure (must match widget's definition)
struct SharedCardData: Codable {
    let name: String
    let localizedName: String?
    let title: String?
    let company: String?
    let vcardString: String
}
