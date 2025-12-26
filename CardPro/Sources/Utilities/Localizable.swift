import Foundation

/// Language manager for in-app language switching
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            bundle = LanguageManager.bundle(for: currentLanguage)
        }
    }

    private(set) var bundle: Bundle

    static let supportedLanguages: [(code: String, name: String, localName: String)] = [
        ("system", "System Default", "跟隨系統"),
        ("en", "English", "English"),
        ("zh-Hant", "Traditional Chinese", "繁體中文"),
        ("zh-Hans", "Simplified Chinese", "简体中文"),
        ("ja", "Japanese", "日本語")
    ]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.currentLanguage = saved
        self.bundle = LanguageManager.bundle(for: saved)
    }

    static func bundle(for languageCode: String) -> Bundle {
        if languageCode == "system" {
            return .main
        }

        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func displayName(for code: String) -> String {
        LanguageManager.supportedLanguages.first { $0.code == code }?.localName ?? code
    }
}

/// String extension for easy localization
extension String {
    /// Returns the localized version of this string key
    var localized: String {
        NSLocalizedString(self, bundle: LanguageManager.shared.bundle, comment: "")
    }

    /// Returns the localized version with arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, bundle: LanguageManager.shared.bundle, comment: ""), arguments: arguments)
    }
}

/// Localization keys namespace - all properties are computed for dynamic language switching
enum L10n {
    // MARK: - Tab Bar
    enum Tab {
        static var myCards: String { "tab.myCards".localized }
        static var received: String { "tab.received".localized }
        static var settings: String { "tab.settings".localized }
    }

    // MARK: - My Cards
    enum MyCards {
        static var title: String { "myCards.title".localized }
        static var emptyTitle: String { "myCards.empty.title".localized }
        static var emptySubtitle: String { "myCards.empty.subtitle".localized }
        static var emptyButton: String { "myCards.empty.button".localized }
        static var setDefault: String { "myCards.setDefault".localized }
        static var defaultCard: String { "myCards.defaultCard".localized }
        static func cardCount(_ current: Int, _ total: Int) -> String {
            "myCards.cardCount".localized(with: current, total)
        }
    }

    // MARK: - Card Editor
    enum CardEditor {
        static var newCard: String { "cardEditor.newCard".localized }
        static var editCard: String { "cardEditor.editCard".localized }
        static var save: String { "cardEditor.save".localized }
        static var cancel: String { "cardEditor.cancel".localized }
        static var delete: String { "cardEditor.delete".localized }
        static var deleteCard: String { "cardEditor.deleteCard".localized }
        static func deleteConfirm(_ name: String) -> String {
            "cardEditor.deleteConfirm".localized(with: name)
        }

        static var cardIdentity: String { "cardEditor.cardIdentity".localized }
        static var cardName: String { "cardEditor.cardName".localized }
        static var cardNameHint: String { "cardEditor.cardNameHint".localized }
        static var myCard: String { "cardEditor.myCard".localized }

        static var profilePhoto: String { "cardEditor.profilePhoto".localized }

        static var cardDesign: String { "cardEditor.cardDesign".localized }
        static var cardDesignHint: String { "cardEditor.cardDesignHint".localized }
        static var addCardDesign: String { "cardEditor.addCardDesign".localized }
        static var scanUploadGenerate: String { "cardEditor.scanUploadGenerate".localized }
        static var change: String { "cardEditor.change".localized }

        static var quickScan: String { "cardEditor.quickScan".localized }
        static var hdPhoto: String { "cardEditor.hdPhoto".localized }
        static var uploadFromPhotos: String { "cardEditor.uploadFromPhotos".localized }
        static var generateFromTemplate: String { "cardEditor.generateFromTemplate".localized }
        static var cropCurrentImage: String { "cardEditor.cropCurrentImage".localized }
        static var removeCardDesign: String { "cardEditor.removeCardDesign".localized }

        static var takeHDPhoto: String { "cardEditor.takeHDPhoto".localized }
        static var takeHDPhotoButton: String { "cardEditor.takeHDPhotoButton".localized }
        static var useScannedImage: String { "cardEditor.useScannedImage".localized }
        static var hdPhotoHint: String { "cardEditor.hdPhotoHint".localized }

        static var nameEnglish: String { "cardEditor.nameEnglish".localized }
        static var nameLocal: String { "cardEditor.nameLocal".localized }
        static var firstName: String { "cardEditor.firstName".localized }
        static var lastName: String { "cardEditor.lastName".localized }

        static var workEnglish: String { "cardEditor.workEnglish".localized }
        static var workLocal: String { "cardEditor.workLocal".localized }
        static var company: String { "cardEditor.company".localized }
        static var title: String { "cardEditor.title".localized }

        static var contact: String { "cardEditor.contact".localized }
        static var phone: String { "cardEditor.phone".localized }
        static var email: String { "cardEditor.email".localized }
        static var website: String { "cardEditor.website".localized }

        static var additionalInfo: String { "cardEditor.additionalInfo".localized }
        static var addField: String { "cardEditor.addField".localized }
        static var additionalInfoHint: String { "cardEditor.additionalInfoHint".localized }

        static var notes: String { "cardEditor.notes".localized }
        static var preview: String { "cardEditor.preview".localized }

        static var ocrError: String { "cardEditor.ocrError".localized }
        static var ocrResults: String { "cardEditor.ocrResults".localized }
        static var scanningCard: String { "cardEditor.scanningCard".localized }
        static var noTextDetected: String { "cardEditor.noTextDetected".localized }
        static var rawText: String { "cardEditor.rawText".localized }
        static var skip: String { "cardEditor.skip".localized }
        static var autoFill: String { "cardEditor.autoFill".localized }

        static var chooseTemplate: String { "cardEditor.chooseTemplate".localized }
        static var useTemplate: String { "cardEditor.useTemplate".localized }
    }

    // MARK: - Received
    enum Received {
        static var title: String { "received.title".localized }
        static var searchPrompt: String { "received.searchPrompt".localized }
        static var allContacts: String { "received.allContacts".localized }

        static var addContact: String { "received.addContact".localized }
        static var scanPhysicalCard: String { "received.scanPhysicalCard".localized }
        static var scanQRCode: String { "received.scanQRCode".localized }
        static var scanNFCTag: String { "received.scanNFCTag".localized }
        static var manualEntry: String { "received.manualEntry".localized }

        static var importAllToContacts: String { "received.importAllToContacts".localized }
        static var syncAllToContacts: String { "received.syncAllToContacts".localized }
        static var importToContacts: String { "received.importToContacts".localized }
        static var importComplete: String { "received.importComplete".localized }
        static func importResult(_ imported: Int, _ updated: Int, _ failed: Int) -> String {
            "received.importResult".localized(with: imported, updated, failed)
        }
        static var startImport: String { "received.startImport".localized }
        static func importing(_ name: String) -> String {
            "received.importing".localized(with: name)
        }
        static func importHint(_ count: Int) -> String {
            "received.importHint".localized(with: count)
        }
        static var duplicateHint: String { "received.duplicateHint".localized }
        static var imported: String { "received.imported".localized }
        static var updated: String { "received.updated".localized }
        static var failed: String { "received.failed".localized }

        static var addToContacts: String { "received.addToContacts".localized }
        static var alreadyInContacts: String { "received.alreadyInContacts".localized }
        static var editContact: String { "received.editContact".localized }
        static var deleteContact: String { "received.deleteContact".localized }
        static var deleteConfirm: String { "received.deleteConfirm".localized }

        static var profilePhoto: String { "received.profilePhoto".localized }
        static var addPhoto: String { "received.addPhoto".localized }
        static var changePhoto: String { "received.changePhoto".localized }
        static var profilePhotoHint: String { "received.profilePhotoHint".localized }
        static var fetchFromGravatar: String { "received.fetchFromGravatar".localized }
        static var takePhoto: String { "received.takePhoto".localized }
        static var chooseFromPhotos: String { "received.chooseFromPhotos".localized }
        static var removePhoto: String { "received.removePhoto".localized }
        static var noGravatarFound: String { "received.noGravatarFound".localized }
    }

    // MARK: - Settings
    enum Settings {
        static var title: String { "settings.title".localized }
        static var sharing: String { "settings.sharing".localized }
        static var preferredMethod: String { "settings.preferredMethod".localized }
        static var airdrop: String { "settings.airdrop".localized }
        static var qrcode: String { "settings.qrcode".localized }
        static var nfc: String { "settings.nfc".localized }

        static var app: String { "settings.app".localized }
        static var hapticFeedback: String { "settings.hapticFeedback".localized }
        static var language: String { "settings.language".localized }

        static var subscription: String { "settings.subscription".localized }
        static var cardproPro: String { "settings.cardproPro".localized }
        static var free: String { "settings.free".localized }

        static var about: String { "settings.about".localized }
        static var version: String { "settings.version".localized }
        static var privacyPolicy: String { "settings.privacyPolicy".localized }
        static var termsOfService: String { "settings.termsOfService".localized }
        static var contactSupport: String { "settings.contactSupport".localized }
    }

    // MARK: - Share
    enum Share {
        static var share: String { "share.share".localized }
        static var qrCode: String { "share.qrCode".localized }
        static var edit: String { "share.edit".localized }
        static var airdrop: String { "share.airdrop".localized }
        static var nfc: String { "share.nfc".localized }
        static var wallet: String { "share.wallet".localized }
        static var shareCard: String { "share.shareCard".localized }
        static var scanToConnect: String { "share.scanToConnect".localized }
        static var saveQRCode: String { "share.saveQRCode".localized }
        static var shareQRCode: String { "share.shareQRCode".localized }
        static var qrCodeSaved: String { "share.qrCodeSaved".localized }
    }

    // MARK: - NFC
    enum NFC {
        static var writeToTag: String { "nfc.writeToTag".localized }
        static var readyToWrite: String { "nfc.readyToWrite".localized }
        static var holdNearTag: String { "nfc.holdNearTag".localized }
        static var writeSuccess: String { "nfc.writeSuccess".localized }
        static var notAvailable: String { "nfc.notAvailable".localized }
    }

    // MARK: - Incoming Card
    enum Incoming {
        static var newCard: String { "incoming.newCard".localized }
        static var sharedWithYou: String { "incoming.sharedWithYou".localized }
        static var cardSaved: String { "incoming.cardSaved".localized }
        static var saveToCardPro: String { "incoming.saveToCardPro".localized }
        static var notNow: String { "incoming.notNow".localized }
        static var receivedCard: String { "incoming.receivedCard".localized }
    }

    // MARK: - Subscription
    enum Subscription {
        static var title: String { "subscription.title".localized }
        static var unlockAll: String { "subscription.unlockAll".localized }
        static var unlimitedCards: String { "subscription.unlimitedCards".localized }
        static var unlimitedCardsDesc: String { "subscription.unlimitedCardsDesc".localized }
        static var icloudSync: String { "subscription.icloudSync".localized }
        static var icloudSyncDesc: String { "subscription.icloudSyncDesc".localized }
        static var premiumTemplates: String { "subscription.premiumTemplates".localized }
        static var premiumTemplatesDesc: String { "subscription.premiumTemplatesDesc".localized }
        static var analytics: String { "subscription.analytics".localized }
        static var analyticsDesc: String { "subscription.analyticsDesc".localized }
        static var yearly: String { "subscription.yearly".localized }
        static var monthly: String { "subscription.monthly".localized }
        static var yearlyPrice: String { "subscription.yearlyPrice".localized }
        static var monthlyPrice: String { "subscription.monthlyPrice".localized }
        static var save17: String { "subscription.save17".localized }
        static var startFreeTrial: String { "subscription.startFreeTrial".localized }
        static func trialHint(_ price: String) -> String {
            "subscription.trialHint".localized(with: price)
        }
    }

    // MARK: - Promo Code
    enum Promo {
        static var title: String { "promo.title".localized }
        static var enterCode: String { "promo.enterCode".localized }
        static var codePlaceholder: String { "promo.codePlaceholder".localized }
        static var apply: String { "promo.apply".localized }
        static var applied: String { "promo.applied".localized }
        static var invalid: String { "promo.invalid".localized }
        static var expired: String { "promo.expired".localized }
        static var alreadyUsed: String { "promo.alreadyUsed".localized }
        static var notFound: String { "promo.notFound".localized }
        static var yourReferralCode: String { "promo.yourReferralCode".localized }
        static var shareReferralCode: String { "promo.shareReferralCode".localized }
        static var referralHint: String { "promo.referralHint".localized }
        static func referralCount(_ count: Int) -> String {
            "promo.referralCount".localized(with: count)
        }
        static func discount(_ percent: Int) -> String {
            "promo.discount".localized(with: percent)
        }
        static var copied: String { "promo.copied".localized }
    }

    // MARK: - Sync
    enum Sync {
        static var title: String { "sync.title".localized }
        static var icloudSync: String { "sync.icloudSync".localized }
        static var enabled: String { "sync.enabled".localized }
        static var disabled: String { "sync.disabled".localized }
        static var syncing: String { "sync.syncing".localized }
        static func lastSync(_ time: String) -> String {
            "sync.lastSync".localized(with: time)
        }
        static var noAccount: String { "sync.noAccount".localized }
        static var restricted: String { "sync.restricted".localized }
        static var unknown: String { "sync.unknown".localized }
        static var temporarilyUnavailable: String { "sync.temporarilyUnavailable".localized }
        static var proFeature: String { "sync.proFeature".localized }
        static var proFeatureDesc: String { "sync.proFeatureDesc".localized }
    }

    // MARK: - Common
    enum Common {
        static var ok: String { "common.ok".localized }
        static var cancel: String { "common.cancel".localized }
        static var save: String { "common.save".localized }
        static var delete: String { "common.delete".localized }
        static var edit: String { "common.edit".localized }
        static var done: String { "common.done".localized }
        static var error: String { "common.error".localized }
        static var success: String { "common.success".localized }
        static var loading: String { "common.loading".localized }
        static var retry: String { "common.retry".localized }
    }
}
