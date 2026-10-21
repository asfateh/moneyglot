import SwiftUI

/// Searchable list of every supported currency, with the person's favourites pinned on top.
struct CurrencyPickerView: View {
    @Binding var selection: String
    var title = "Currency"

    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currency
    @AppStorage(SettingsKey.favoriteCurrencies) private var favoritesRaw = ""
    @State private var searchText = ""

    private var favorites: [String] { FavoriteCurrencies.decode(favoritesRaw) }

    private var matchingCodes: [String] {
        let codes = currency.availableCodes
        guard !searchText.isEmpty else { return codes }
        return codes.filter {
            $0.localizedCaseInsensitiveContains(searchText)
                || CurrencyCatalog.name(for: $0).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        ForEach(favorites, id: \.self, content: row)
                    } header: {
                        Text("Your currencies")
                    } footer: {
                        Text("Tap the star to add or remove a currency from this list.")
                    }
                }
                Section(searchText.isEmpty ? "All currencies" : "Results") {
                    ForEach(matchingCodes, id: \.self, content: row)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search name or code")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ code: String) -> some View {
        HStack(spacing: 12) {
            Button {
                selection = code
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Text(CurrencyCatalog.flag(for: code)).font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(code).font(.headline)
                        Text(CurrencyCatalog.name(for: code))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if code == selection {
                        Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite(code)
            } label: {
                Image(systemName: favorites.contains(code) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(favorites.contains(code) ? "Remove from your currencies" : "Add to your currencies")
        }
    }

    private func toggleFavorite(_ code: String) {
        var list = favorites
        if let index = list.firstIndex(of: code) {
            guard list.count > 1 else { return }
            list.remove(at: index)
        } else {
            list.append(code)
        }
        favoritesRaw = FavoriteCurrencies.encode(list)
    }
}
