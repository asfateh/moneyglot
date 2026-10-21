import SwiftData
import SwiftUI

@main
struct MoneyglotApp: App {
    @State private var currency = CurrencyService()
    @State private var store = StoreManager()
    @State private var advisor = AIAdvisor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(currency)
                .environment(store)
                .environment(advisor)
        }
        .modelContainer(for: [Entry.self, RecurringPayment.self])
    }
}
