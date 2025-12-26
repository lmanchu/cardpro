import AppIntents
import SwiftUI

// MARK: - Show QR Code Intent

struct ShowQRCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Business Card QR Code"
    static var description = IntentDescription("Display QR code for your default business card")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Set a flag to show QR code when app opens
        UserDefaults.standard.set(true, forKey: "showQRCodeFromShortcut")
        NotificationCenter.default.post(name: .showQRCodeFromShortcut, object: nil)

        return .result(dialog: "Opening QR Code...")
    }
}

// MARK: - Share Card Intent

struct ShareCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Share Business Card"
    static var description = IntentDescription("Share your default business card")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Set a flag to show share sheet when app opens
        UserDefaults.standard.set(true, forKey: "shareCardFromShortcut")
        NotificationCenter.default.post(name: .shareCardFromShortcut, object: nil)

        return .result(dialog: "Opening share options...")
    }
}

// MARK: - Get Card Info Intent (doesn't open app)

struct GetCardInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Business Card Info"
    static var description = IntentDescription("Get your default business card information")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get card info from UserDefaults or shared container
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "defaultCardName") ?? "No card set"
        let title = defaults.string(forKey: "defaultCardTitle") ?? ""
        let company = defaults.string(forKey: "defaultCardCompany") ?? ""

        var info = name
        if !title.isEmpty || !company.isEmpty {
            info += "\n\(title)"
            if !company.isEmpty {
                info += " at \(company)"
            }
        }

        return .result(dialog: IntentDialog(stringLiteral: info))
    }
}

// MARK: - App Shortcuts Provider

struct CardProShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowQRCodeIntent(),
            phrases: [
                "Show my business card in \(.applicationName)",
                "Show QR code in \(.applicationName)",
                "Display my card in \(.applicationName)",
                "\(.applicationName) QR code"
            ],
            shortTitle: "Show QR Code",
            systemImageName: "qrcode"
        )

        AppShortcut(
            intent: ShareCardIntent(),
            phrases: [
                "Share my business card with \(.applicationName)",
                "Share card in \(.applicationName)",
                "Send my card with \(.applicationName)"
            ],
            shortTitle: "Share Card",
            systemImageName: "square.and.arrow.up"
        )

        AppShortcut(
            intent: GetCardInfoIntent(),
            phrases: [
                "What's my business card info in \(.applicationName)",
                "Get my card info from \(.applicationName)"
            ],
            shortTitle: "Get Card Info",
            systemImageName: "person.text.rectangle"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showQRCodeFromShortcut = Notification.Name("showQRCodeFromShortcut")
    static let shareCardFromShortcut = Notification.Name("shareCardFromShortcut")
}
