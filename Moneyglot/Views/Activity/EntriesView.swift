import SwiftData
import SwiftUI

struct EntriesView: View {
    enum KindFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case expenses = "Expenses"
        case income = "Income"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyService.self) private var currency
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @State private var searchText = ""
    @State private var filter: KindFilter = .all
    @State private var showingNewEntry = false
    @State private var editingEntry: Entry?

    private var filteredEntries: [Entry] {
        entries.filter { entry in
            switch filter {
            case .all: break
            case .expenses: guard entry.kind == .expense else { return false }
            case .income: guard entry.kind == .income else { return false }
            }
            guard !searchText.isEmpty else { return true }
            return entry.displayTitle.localizedCaseInsensitiveContains(searchText)
                || entry.category.title.localizedCaseInsensitiveContains(searchText)
                || entry.note.localizedCaseInsensitiveContains(searchText)
                || entry.currencyCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sections: [(month: Date, entries: [Entry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.month) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            Button { editingEntry = entry } label: {
                                EntryRow(entry: entry, reportCurrency: reportCurrency)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(entry) }
                            }
                            .swipeActions(edge: .leading) {
                                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(entry) }
                                    .tint(.indigo)
                            }
                        }
                    } header: {
                        HStack {
                            Text(section.month.formatted(.dateTime.month(.wide).year()))
                            Spacer()
                            Text(net(of: section.entries).money(reportCurrency))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No entries yet", systemImage: "tray")
                    } description: {
                        Text("Add your income, bills, loan payments and everyday spending in any currency.")
                    } actions: {
                        Button("Add entry") { showingNewEntry = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search entries")
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Show", selection: $filter) {
                            ForEach(KindFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Filter", systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add entry", systemImage: "plus") { showingNewEntry = true }
                }
            }
            .sheet(isPresented: $showingNewEntry) { EntryEditorView() }
            .sheet(item: $editingEntry) { EntryEditorView(entry: $0) }
        }
    }

    private func net(of entries: [Entry]) -> Decimal {
        entries.reduce(Decimal(0)) { total, entry in
            let value = currency.converter.convert(entry.amount, from: entry.currencyCode, to: reportCurrency) ?? 0
            return entry.kind == .income ? total + value : total - value
        }
    }

    private func delete(_ entry: Entry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func duplicate(_ entry: Entry) {
        let copy = Entry(
            title: entry.title,
            amount: entry.amount,
            currencyCode: entry.currencyCode,
            date: .now,
            category: entry.category,
            paymentMethod: entry.paymentMethod,
            note: entry.note
        )
        modelContext.insert(copy)
        try? modelContext.save()
    }
}
