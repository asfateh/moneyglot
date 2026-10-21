import Foundation
import Observation
import StoreKit

/// Handles the Moneyglot Pro auto-renewable subscription with StoreKit 2.
@MainActor
@Observable
final class StoreManager {
    static let proMonthlyID = "com.moneyglot.app.pro.monthly"
    static let productIDs = [proMonthlyID]

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private var updatesTask: Task<Void, Never>?

    #if DEBUG
    /// Lets you preview Pro screens in the Simulator without a purchase. Never compiled into release builds.
    var debugProUnlocked = UserDefaults.standard.bool(forKey: "debugProUnlocked") {
        didSet { UserDefaults.standard.set(debugProUnlocked, forKey: "debugProUnlocked") }
    }
    var hasPro: Bool { isSubscribed || debugProUnlocked }
    #else
    var hasPro: Bool { isSubscribed }
    #endif

    var proProduct: Product? { products.first { $0.id == Self.proMonthlyID } }

    /// Loads products and entitlements and starts listening for renewals, refunds and Ask to Buy approvals.
    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
