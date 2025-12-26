import Foundation
import StoreKit

/// Subscription product identifiers - must match App Store Connect
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.lman.cardpro.pro.monthly"
    case yearly = "com.lman.cardpro.pro.yearly"

    var displayName: String {
        switch self {
        case .monthly: return L10n.Subscription.monthly
        case .yearly: return L10n.Subscription.yearly
        }
    }
}

/// Subscription status
enum SubscriptionStatus: Equatable {
    case free
    case pro(expirationDate: Date?)
    case expired

    var isPro: Bool {
        if case .pro = self { return true }
        return false
    }
}

/// StoreKit 2 based subscription service
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // DEBUG: Set to true to simulate Pro status for testing
    #if DEBUG
    private static let debugForceProStatus = true
    #else
    private static let debugForceProStatus = false
    #endif

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .free
    @Published private(set) var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Free tier limits
    static let freeCardLimit = 2

    var canCreateMoreCards: Bool {
        subscriptionStatus.isPro
    }

    func hasReachedFreeLimit(currentCardCount: Int) -> Bool {
        !subscriptionStatus.isPro && currentCardCount >= Self.freeCardLimit
    }

    // MARK: - Initialization

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = SubscriptionProduct.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)

            // Sort: yearly first (better value)
            products = storeProducts.sorted { product1, product2 in
                if product1.id.contains("yearly") { return true }
                if product2.id.contains("yearly") { return false }
                return product1.price < product2.price
            }

            print("✅ Loaded \(products.count) products")
        } catch {
            print("❌ Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check verification
            let transaction = try Self.checkVerified(verification)

            // Update subscription status
            await updateSubscriptionStatus()

            // Finish the transaction
            await transaction.finish()

            return true

        case .userCancelled:
            return false

        case .pending:
            // Transaction is pending (e.g., Ask to Buy)
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        // This will trigger the transaction listener for any valid transactions
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        // DEBUG: Force Pro status for testing
        if Self.debugForceProStatus {
            subscriptionStatus = .pro(expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()))
            print("🔧 DEBUG: Forced Pro status")
            return
        }

        var hasActiveSubscription = false
        var latestExpirationDate: Date?

        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)

                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true

                    if let expirationDate = transaction.expirationDate {
                        if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                            latestExpirationDate = expirationDate
                        }
                    }
                }
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }

        if hasActiveSubscription {
            subscriptionStatus = .pro(expirationDate: latestExpirationDate)
            print("✅ Pro subscription active until: \(latestExpirationDate?.description ?? "unknown")")
        } else {
            subscriptionStatus = .free
            print("ℹ️ Free tier")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)

                    // Update subscription status on main actor
                    await self.updateSubscriptionStatus()

                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helpers

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func product(for identifier: SubscriptionProduct) -> Product? {
        products.first { $0.id == identifier.rawValue }
    }
}

// MARK: - Errors

enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}
