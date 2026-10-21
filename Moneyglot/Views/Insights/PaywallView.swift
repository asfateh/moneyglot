import StoreKit
import SwiftUI

/// Apple's built-in subscription store UI: shows price, period, trial, restore, terms and privacy links.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.productIDs) {
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.brandGradient)
                Text("Moneyglot Pro")
                    .font(.largeTitle.weight(.bold))
                Text("Your private AI money coach")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    benefit("wand.and.stars", "A personal savings plan built from your real numbers")
                    benefit("lightbulb.fill", "Smart insights on spikes, debt, subscriptions and FX fees")
                    benefit("lock.shield.fill", "Runs on your iPhone — your data never leaves it")
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: AppLinks.termsOfUse, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(let verification)) = result {
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await store.refreshEntitlements()
                dismiss()
            }
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.teal)
        }
    }
}
