import StoreKit

@Observable
final class SubscriptionManager {
    var tier: SubscriptionTier = .free
    var products: [Product] = []

    private let productLoader: @Sendable ([String]) async throws -> [Product]
    private let entitlementIDsProvider: @Sendable () -> AsyncStream<String>
    private let transactionUpdateIDsProvider: @Sendable () -> AsyncStream<String>
    private let syncHandler: @Sendable () async throws -> Void
    private var transactionListener: Task<Void, Never>?

    init(
        productLoader: (@Sendable ([String]) async throws -> [Product])? = nil,
        entitlementIDsProvider: (@Sendable () -> AsyncStream<String>)? = nil,
        transactionUpdateIDsProvider: (@Sendable () -> AsyncStream<String>)? = nil,
        syncHandler: (@Sendable () async throws -> Void)? = nil,
        startTransactionListener: Bool = true
    ) {
        self.productLoader = productLoader ?? { ids in
            try await Product.products(for: ids)
        }
        self.entitlementIDsProvider = entitlementIDsProvider ?? {
            AsyncStream { continuation in
                let task = Task {
                    for await result in Transaction.currentEntitlements {
                        guard case .verified(let transaction) = result else { continue }
                        continuation.yield(transaction.productID)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        self.transactionUpdateIDsProvider = transactionUpdateIDsProvider ?? {
            AsyncStream { continuation in
                let task = Task {
                    for await result in Transaction.updates {
                        guard case .verified(let transaction) = result else { continue }
                        continuation.yield(transaction.productID)
                        await transaction.finish()
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        self.syncHandler = syncHandler ?? {
            try await AppStore.sync()
        }

        if startTransactionListener {
            transactionListener = Task {
                await listenForTransactions()
            }
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
            products = try await productLoader(productIDs)
        } catch {
            print("Failed to load products: \(error)")
            products = []
        }
    }

    @MainActor
    private func checkEntitlements() async {
        var hasPremiumEntitlement = false

        for await productID in entitlementIDsProvider() {
            if PremiumProductID.allCases.map({ $0.rawValue }).contains(productID) {
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
            try await syncHandler()
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
        for await productID in transactionUpdateIDsProvider() {
            if PremiumProductID.allCases.map({ $0.rawValue }).contains(productID) {
                await checkEntitlements()
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
