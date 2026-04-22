import Combine
import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    @Published var isLoadingProducts: Bool = false
    @Published var productLoadError: String? = nil

    private let productIds: [String] = [
        "com.scrollmate.tip.bronze",
        "com.scrollmate.tip.silver",
        "com.scrollmate.tip.gold",
        "com.scrollmate.tip.emerald",
        "com.scrollmate.tip.diamond",
    ]

    private var transactionListener: Task<Void, Never>? = nil

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoadingProducts = true
        productLoadError = nil
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: productIds)
            products = fetched.sorted { $0.price < $1.price }
            if fetched.isEmpty {
                productLoadError = String(localized: "tip.error.loadfailed")
            }
        } catch {
            productLoadError = String(localized: "tip.error.loadfailed")
            print("StoreKit: failed to load products — \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await applyPurchase(productId: transaction.productID)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            print("StoreKit: purchase error — \(error)")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            // Re-check all current entitlements after sync
            for await result in Transaction.currentEntitlements {
                if let transaction = try? checkVerified(result) {
                    await applyPurchase(productId: transaction.productID)
                    await transaction.finish()
                }
            }
        } catch {
            purchaseError = "Restore failed. Please try again."
            print("StoreKit: restore error — \(error)")
        }
    }

    // MARK: - Listen for transactions (handles purchases from outside the app)

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    await applyPurchase(productId: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Restore on launch

    func restoreOnLaunch() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await applyPurchase(productId: transaction.productID)
                await transaction.finish()
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    private func applyPurchase(productId: String) async {
        guard let tier = TipTier.allCases.first(where: { $0.productId == productId }) else { return }
        SharedStorage.shared.purchasedTier = tier
    }

    // MARK: - Price label for a tier

    func priceLabel(for tier: TipTier) -> String {
        guard let product = products.first(where: { $0.id == tier.productId }) else {
            return tier.price // fallback to hardcoded
        }
        return product.displayPrice
    }
}

enum StoreError: Error {
    case failedVerification
}
