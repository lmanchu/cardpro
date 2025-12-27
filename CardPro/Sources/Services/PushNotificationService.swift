import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

// MARK: - Card Update Notification

struct CardUpdateNotification: Identifiable {
    let id: String
    let cardId: String
    let cardOwnerName: String
    let version: Int
    let receivedAt: Date
}

// MARK: - Push Notification Service

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var fcmToken: String?
    @Published private(set) var isAuthorized = false
    @Published private(set) var pendingNotifications: [CardUpdateNotification] = []

    private let firebaseService = FirebaseService.shared

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        // Set FCM delegate
        Messaging.messaging().delegate = self

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Check current authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Request Permission

    /// Request notification permission
    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)

            isAuthorized = granted

            if granted {
                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("🔔 Notification permission granted")
            } else {
                print("🔔 Notification permission denied")
            }

            return granted
        } catch {
            print("🔔 Error requesting notification permission: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Token Management

    /// Update FCM token on Firebase
    func updateToken() async {
        guard let token = fcmToken else { return }

        do {
            try await firebaseService.updateFCMToken(token)
            print("🔔 FCM token updated on Firebase")
        } catch {
            print("🔔 Error updating FCM token: \(error)")
        }
    }

    /// Handle APNs token
    func handleAPNsToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - Handle Notifications

    /// Handle incoming notification
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "card_update":
            handleCardUpdate(userInfo)
        default:
            print("🔔 Unknown notification type: \(type)")
        }
    }

    private func handleCardUpdate(_ userInfo: [AnyHashable: Any]) {
        guard let cardId = userInfo["cardId"] as? String,
              let versionString = userInfo["version"] as? String,
              let version = Int(versionString) else {
            return
        }

        let notification = CardUpdateNotification(
            id: UUID().uuidString,
            cardId: cardId,
            cardOwnerName: userInfo["cardOwnerName"] as? String ?? "Unknown",
            version: version,
            receivedAt: Date()
        )

        pendingNotifications.append(notification)

        print("🔔 Received card update notification: \(cardId) v\(version)")

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .cardUpdateReceived,
            object: nil,
            userInfo: ["notification": notification]
        )
    }

    /// Clear a pending notification
    func clearNotification(_ notification: CardUpdateNotification) {
        pendingNotifications.removeAll { $0.id == notification.id }
    }

    /// Clear all notifications for a card
    func clearNotifications(forCardId cardId: String) {
        pendingNotifications.removeAll { $0.cardId == cardId }
    }

    // MARK: - Local Notifications

    /// Schedule a local notification
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        delay: TimeInterval = 0
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger: UNNotificationTrigger?
        if delay > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            trigger = nil
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Scheduled local notification: \(title)")
        } catch {
            print("🔔 Error scheduling notification: \(error)")
        }
    }
}

// MARK: - FCM Delegate

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = token
            print("🔔 FCM token: \(token)")

            // Update token on Firebase
            await self.updateToken()
        }
    }
}

// MARK: - Notification Center Delegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        Task { @MainActor in
            handleNotification(userInfo)
        }

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            handleNotification(userInfo)
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cardUpdateReceived = Notification.Name("cardUpdateReceived")
}
