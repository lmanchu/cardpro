import Foundation
import StoreKit

// MARK: - Promo Code Types

enum PromoCodeType: String, Codable {
    case special    // Admin-defined codes (e.g., CARDPRO50)
    case referral   // User-generated referral codes
}

enum PromoDiscount: Codable, Equatable {
    case percentOff(Int)      // e.g., 50 for 50% off
    case freeMonths(Int)      // e.g., 3 for 3 free months

    var displayText: String {
        switch self {
        case .percentOff(let percent):
            return "\(percent)% OFF"
        case .freeMonths(let months):
            return "\(months) Months Free"
        }
    }
}

// MARK: - Promo Code Model

struct PromoCode: Codable, Identifiable {
    let id: UUID
    let code: String
    let type: PromoCodeType
    let discount: PromoDiscount
    let validUntil: Date?
    let maxUses: Int?
    var currentUses: Int
    let appStoreOfferID: String?  // For StoreKit promotional offers

    var isValid: Bool {
        // Check expiration
        if let validUntil = validUntil, Date() > validUntil {
            return false
        }
        // Check max uses
        if let maxUses = maxUses, currentUses >= maxUses {
            return false
        }
        return true
    }
}

// MARK: - User Referral

struct UserReferral: Codable {
    let referralCode: String
    var referralCount: Int
    var rewardsEarned: Int  // Number of months earned
    let createdAt: Date

    static func generateCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // Excluding confusing chars
        let randomPart = String((0..<6).map { _ in characters.randomElement()! })
        return "REF-\(randomPart)"
    }
}

// MARK: - Promo Code Result

enum PromoCodeResult {
    case valid(PromoCode)
    case invalid(String)
    case expired
    case alreadyUsed
    case notFound
}

// MARK: - Promo Code Service

@MainActor
class PromoCodeService: ObservableObject {
    static let shared = PromoCodeService()

    @Published private(set) var userReferral: UserReferral?
    @Published private(set) var appliedPromoCode: PromoCode?
    @Published private(set) var isLoading = false

    private let userDefaults = UserDefaults.standard
    private let referralKey = "userReferralCode"
    private let appliedCodeKey = "appliedPromoCode"
    private let usedCodesKey = "usedPromoCodes"

    // MARK: - Predefined Special Codes

    private var specialCodes: [PromoCode] {
        [
            PromoCode(
                id: UUID(),
                code: "CARDPRO50",
                type: .special,
                discount: .percentOff(50),
                validUntil: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
                maxUses: 1000,
                currentUses: 0,
                appStoreOfferID: "cardpro_50off_yearly"
            ),
            PromoCode(
                id: UUID(),
                code: "LAUNCH2024",
                type: .special,
                discount: .percentOff(30),
                validUntil: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 31)),
                maxUses: 500,
                currentUses: 0,
                appStoreOfferID: "cardpro_30off_launch"
            ),
            PromoCode(
                id: UUID(),
                code: "FRIEND20",
                type: .referral,
                discount: .percentOff(20),
                validUntil: nil,
                maxUses: nil,
                currentUses: 0,
                appStoreOfferID: "cardpro_20off_referral"
            )
        ]
    }

    // MARK: - Initialization

    private init() {
        loadUserReferral()
        loadAppliedCode()
    }

    // MARK: - User Referral Code

    /// Get or create user's referral code
    func getUserReferralCode() -> String {
        if let referral = userReferral {
            return referral.referralCode
        }

        // Generate new referral code
        let newReferral = UserReferral(
            referralCode: UserReferral.generateCode(),
            referralCount: 0,
            rewardsEarned: 0,
            createdAt: Date()
        )

        userReferral = newReferral
        saveUserReferral()

        return newReferral.referralCode
    }

    /// Increment referral count when someone uses this user's code
    func incrementReferralCount() {
        guard var referral = userReferral else { return }
        referral.referralCount += 1

        // Award 1 free month for every successful referral
        referral.rewardsEarned += 1

        userReferral = referral
        saveUserReferral()
    }

    // MARK: - Promo Code Validation

    /// Validate and apply a promo code
    func validateCode(_ code: String) async -> PromoCodeResult {
        isLoading = true
        defer { isLoading = false }

        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        // Check if already used
        if hasUsedCode(normalizedCode) {
            return .alreadyUsed
        }

        // Check special codes
        if let specialCode = specialCodes.first(where: { $0.code == normalizedCode }) {
            if !specialCode.isValid {
                return .expired
            }
            return .valid(specialCode)
        }

        // Check if it's a referral code (REF-XXXXXX format)
        if normalizedCode.hasPrefix("REF-") {
            // In production, validate against backend
            // For now, accept any REF- code
            let referralPromo = PromoCode(
                id: UUID(),
                code: normalizedCode,
                type: .referral,
                discount: .percentOff(20),
                validUntil: nil,
                maxUses: nil,
                currentUses: 0,
                appStoreOfferID: "cardpro_20off_referral"
            )
            return .valid(referralPromo)
        }

        return .notFound
    }

    /// Apply a validated promo code
    func applyCode(_ promoCode: PromoCode) {
        appliedPromoCode = promoCode
        markCodeAsUsed(promoCode.code)
        saveAppliedCode()

        // If it's a referral code, notify the referrer (in production, via backend)
        if promoCode.type == .referral {
            // TODO: Send notification to referrer via backend
            print("📣 Referral code used: \(promoCode.code)")
        }
    }

    /// Clear applied promo code
    func clearAppliedCode() {
        appliedPromoCode = nil
        userDefaults.removeObject(forKey: appliedCodeKey)
    }

    /// Get discount description for display
    func discountDescription(for discount: PromoDiscount) -> String {
        switch discount {
        case .percentOff(let percent):
            return L10n.Promo.discount(percent)
        case .freeMonths(let months):
            return "\(months) Months Free"
        }
    }

    // MARK: - StoreKit Integration

    /// Get promotional offer for StoreKit purchase
    func getPromotionalOffer(for product: Product) async -> Product.PurchaseOption? {
        guard let promoCode = appliedPromoCode,
              let offerID = promoCode.appStoreOfferID else {
            return nil
        }

        // In production, you need to:
        // 1. Request a signature from your server
        // 2. Use Product.PromotionalOffer with the signature
        // For now, return nil (promotional offers require server-side signing)

        print("🎫 Would apply offer: \(offerID) for product: \(product.id)")
        return nil
    }

    // MARK: - Persistence

    private func loadUserReferral() {
        if let data = userDefaults.data(forKey: referralKey),
           let referral = try? JSONDecoder().decode(UserReferral.self, from: data) {
            userReferral = referral
        }
    }

    private func saveUserReferral() {
        if let referral = userReferral,
           let data = try? JSONEncoder().encode(referral) {
            userDefaults.set(data, forKey: referralKey)
        }
    }

    private func loadAppliedCode() {
        if let data = userDefaults.data(forKey: appliedCodeKey),
           let code = try? JSONDecoder().decode(PromoCode.self, from: data) {
            appliedPromoCode = code
        }
    }

    private func saveAppliedCode() {
        if let code = appliedPromoCode,
           let data = try? JSONEncoder().encode(code) {
            userDefaults.set(data, forKey: appliedCodeKey)
        }
    }

    private func hasUsedCode(_ code: String) -> Bool {
        let usedCodes = userDefaults.stringArray(forKey: usedCodesKey) ?? []
        return usedCodes.contains(code)
    }

    private func markCodeAsUsed(_ code: String) {
        var usedCodes = userDefaults.stringArray(forKey: usedCodesKey) ?? []
        usedCodes.append(code)
        userDefaults.set(usedCodes, forKey: usedCodesKey)
    }
}

// MARK: - Promo Code Display Helpers

extension PromoCode {
    var discountBadgeColor: String {
        switch discount {
        case .percentOff(let percent):
            if percent >= 50 { return "red" }
            if percent >= 30 { return "orange" }
            return "green"
        case .freeMonths:
            return "purple"
        }
    }
}
