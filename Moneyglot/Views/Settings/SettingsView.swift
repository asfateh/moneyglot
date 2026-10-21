import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(CurrencyService.self) private var currency
    @Query private var entries: [Entry]
    @Query private var schedules: [RecurringPayment]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @State private var showingCurrencyPicker = false
    @State private var showingPaywall = false
    @State private var showingManageSubscription = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showingCurrencyPicker = true } label: {
                        LabeledContent("Report currency") {
                            Text(CurrencyCatalog.label(for: reportCurrency))
                        }
                    }
                    .tint(.primary)
                    NavigationLink {
                        ExchangeRatesView()
                    } label: {
                        LabeledContent("Exchange rates") {
                            Text(currency.lastUpdated, format: .relative(presentation: .named))
                        }
                    }
                } header: {
                    Text("Currencies")
                } footer: {
                    Text("Every entry keeps its original currency. Totals and reports are shown in your report currency.")
                }

                Section("Payments") {
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        LabeledContent("Repeating payments") {
                            Text("\(schedules.filter(\.isActive).count) active")
                        }
                    }
                }

                Section {
                    if store.hasPro {
                        LabeledContent("Status") {
                            Label("Active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                        Button("Manage subscription") { showingManageSubscription = true }
                    } else {
                        Button { showingPaywall = true } label: {
                            Label("Upgrade to Pro", systemImage: "sparkles")
                        }
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                } header: {
                    Text("Moneyglot Pro")
                } footer: {
                    Text("AI savings plan and smart insights.")
                }

                Section("Your data") {
                    ShareLink(
                        item: CSVDocument(
                            filename: "Moneyglot export.csv",
                            text: CSVExporter.csv(for: entries, converter: currency.converter, reportCurrency: reportCurrency)
                        ),
                        preview: SharePreview("Moneyglot export")
                    ) {
                        Label("Export all entries (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    Button("Delete all data", role: .destructive) { confirmingDelete = true }
                        .disabled(entries.isEmpty && schedules.isEmpty)
                }

                Section {
                    Link(destination: AppLinks.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: AppLinks.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                    Link(destination: AppLinks.support) {
                        Label("Help & Support", systemImage: "questionmark.circle.fill")
                    }
                    LabeledContent("Version", value: Self.appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Your entries are stored only on this iPhone and included in your device backups.")
                }

                #if DEBUG
                DeveloperSection()
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selection: $reportCurrency, title: "Report currency")
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
            .confirmationDialog("Delete all entries and repeating payments?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive, action: deleteAll)
            } message: {
                Text("This can't be undone. Export a CSV first if you want a copy.")
            }
        }
    }

    private func deleteAll() {
        entries.forEach { modelContext.delete($0) }
        schedules.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#if DEBUG
private struct DeveloperSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store

    var body: some View {
        @Bindable var store = store
        Section {
            Button("Load sample data") { SampleData.load(into: modelContext) }
            Toggle("Unlock Pro", isOn: $store.debugProUnlocked)
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug builds only — not included in the App Store version.")
        }
    }
}
#endif
