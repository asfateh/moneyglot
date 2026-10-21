import SwiftData
import SwiftUI

enum AppTab: String, Hashable {
    case overview, activity, reports, insights, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrencyService.self) private var currency
    @Environment(StoreManager.self) private var store
    @State private var selection = RootView.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("Overview", systemImage: "house.fill", value: AppTab.overview) {
                HomeView(selection: $selection)
            }
            Tab("Activity", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.activity) {
                EntriesView()
            }
            Tab("Reports", systemImage: "chart.pie.fill", value: AppTab.reports) {
                ReportsView()
            }
            Tab("Insights", systemImage: "sparkles", value: AppTab.insights) {
                InsightsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .task { await startUp() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            RecurringScheduler.run(in: modelContext)
            Task { await currency.refreshIfStale() }
        }
    }

    private func startUp() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "seedSampleData") {
            SampleData.load(into: modelContext)
        }
        #endif
        RecurringScheduler.run(in: modelContext)
        await store.start()
        await currency.refreshIfStale()
    }

    /// Launch argument `-initialTab reports` opens a specific tab (used for screenshots).
    private static var initialTab: AppTab {
        #if DEBUG
        UserDefaults.standard.string(forKey: "initialTab").flatMap(AppTab.init(rawValue:)) ?? .overview
        #else
        .overview
        #endif
    }
}

#if DEBUG
#Preview {
    let container = try! ModelContainer(for: Entry.self, RecurringPayment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SampleData.load(into: container.mainContext)
    return RootView()
        .modelContainer(container)
        .environment(CurrencyService())
        .environment(StoreManager())
        .environment(AIAdvisor())
}
#endif
