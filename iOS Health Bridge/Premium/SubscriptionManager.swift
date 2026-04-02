import StoreKit

@Observable
final class SubscriptionManager {
    var tier: SubscriptionTier = .free
    var products: [Product] = []

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task {
            await listenForTransactions()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    @MainActor
    func loadSubscriptionStatus() async {
        await loadProducts()
        await checkEntitlements()
    }

    @MainActor
    private func loadProducts() async {
        let productIDs = PremiumProductID.allCases.map { $0.rawValue }
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
            products = []
        }
    }

    @MainActor
    private func checkEntitlements() async {
        var hasPremiumEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            let productID = transaction.productID
            if PremiumProductID.allCases.map({ $0.rawValue }).contains(productID) {
                // Transaction.currentEntitlements already excludes expired
                // subscriptions, so any verified transaction here is active.
                hasPremiumEntitlement = true
                if productID == PremiumProductID.lifetime.rawValue { break }
            }
        }

        tier = hasPremiumEntitlement ? .premium : .free
    }

    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    @MainActor
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await checkEntitlements()
            return tier == .premium
        } catch {
            print("Restore failed: \(error)")
            return false
        }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == PremiumProductID.monthly.rawValue }
    }

    var annualProduct: Product? {
        products.first { $0.id == PremiumProductID.annual.rawValue }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == PremiumProductID.lifetime.rawValue }
    }

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("Transaction verification failed: \(error)")
            throw StoreError.failedVerification
        case .verified(let verified):
            return verified
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await checkEntitlements()
                await transaction.finish()
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
