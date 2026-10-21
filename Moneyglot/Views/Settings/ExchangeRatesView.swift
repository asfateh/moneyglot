import SwiftUI

struct ExchangeRatesView: View {
    @Environment(CurrencyService.self) private var currency
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @AppStorage(SettingsKey.favoriteCurrencies) private var favoritesRaw = ""
    @State private var searchText = ""

    private var codes: [String] {
        let all = currency.availableCodes.filter { $0 != reportCurrency }
        guard !searchText.isEmpty else {
            let favorites = FavoriteCurrencies.decode(favoritesRaw).filter { $0 != reportCurrency }
            return favorites + all.filter { !favorites.contains($0) }
        }
        return all.filter {
            $0.localizedCaseInsensitiveContains(searchText)
                || CurrencyCatalog.name(for: $0).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Source", value: currency.source == .live ? "ExchangeRate-API" : "Built-in (offline)")
                LabeledContent("Rates as of", value: currency.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                Button {
                    Task { await currency.refresh() }
                } label: {
                    HStack {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                        if currency.isRefreshing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(currency.isRefreshing)
                if let error = currency.lastError {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            } footer: {
                Link("Rates by Exchange Rate API", destination: AppLinks.exchangeRateAttribution)
                    .font(.footnote)
            }

            Section("1 \(reportCurrency) equals") {
                ForEach(codes, id: \.self) { code in
                    LabeledContent {
                        if let rate = currency.converter.rate(from: reportCurrency, to: code) {
                            Text(rate.doubleValue, format: .number.precision(.significantDigits(2...6)))
                                .monospacedDigit()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(CurrencyCatalog.flag(for: code))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(code).font(.subheadline.weight(.semibold))
                                Text(CurrencyCatalog.name(for: code)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search currency")
        .refreshable { await currency.refresh() }
        .navigationTitle("Exchange Rates")
        .navigationBarTitleDisplayMode(.inline)
    }
}
