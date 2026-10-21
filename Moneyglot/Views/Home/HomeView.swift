import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var selection: AppTab
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyService.self) private var currency
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(filter: #Predicate<RecurringPayment> { $0.isActive }) private var schedules: [RecurringPayment]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @State private var showingNewEntry = false
    @State private var editingEntry: Entry?

    var body: some View {
        let report = ReportBuilder(converter: currency.converter)
            .build(entries.map(\.snapshot), period: .month, containing: .now, currency: reportCurrency)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if entries.isEmpty {
                        welcome
                    } else {
                        MonthSummaryCard(report: report)
                        if report.expenses > 0 {
                            SpendingGroupsCard(report: report)
                        }
                        upcomingCard
                        recentCard
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add entry", systemImage: "plus") { showingNewEntry = true }
                }
            }
            .sheet(isPresented: $showingNewEntry) { EntryEditorView() }
            .sheet(item: $editingEntry) { EntryEditorView(entry: $0) }
        }
    }

    private var welcome: some View {
        ContentUnavailableView {
            Label("Welcome to Moneyglot", systemImage: "globe.americas.fill")
        } description: {
            Text("Track income, bills, loans and everyday spending in any currency — then see it all in the one you choose.")
        } actions: {
            Button("Add your first entry") { showingNewEntry = true }
                .buttonStyle(.borderedProminent)
            #if DEBUG
            Button("Load sample data") { SampleData.load(into: modelContext) }
            #endif
        }
        .padding(.top, 60)
    }

    private var upcomingSchedules: [(payment: RecurringPayment, date: Date)] {
        let horizon = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        return schedules
            .compactMap { payment in payment.nextDueDate.map { (payment, $0) } }
            .filter { $0.date <= horizon }
            .sorted { $0.date < $1.date }
    }

    @ViewBuilder
    private var upcomingCard: some View {
        let upcoming = upcomingSchedules.prefix(4)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Coming up", subtitle: "Next 30 days")
                ForEach(upcoming, id: \.payment.id) { item in
                    HStack(spacing: 12) {
                        CategoryIcon(category: item.payment.category, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.payment.displayTitle).font(.subheadline.weight(.medium))
                            Text(item.date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.payment.amount.money(item.payment.currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(item.payment.category.kind == .income ? Color.green : Color.primary)
                    }
                }
            }
            .card()
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardHeader(title: "Recent activity")
                Button("See all") { selection = .activity }
                    .font(.subheadline.weight(.medium))
            }
            ForEach(entries.prefix(5)) { entry in
                Button { editingEntry = entry } label: {
                    EntryRow(entry: entry, reportCurrency: reportCurrency)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

private struct MonthSummaryCard: View {
    let report: Report

    var body: some View {
        let code = report.currency
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(ReportPeriod.month.label(for: report.interval))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(CurrencyCatalog.label(for: code))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.18), in: .capsule)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Left over this month")
                    .font(.footnote)
                    .opacity(0.85)
                Text(report.net.money(code))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            HStack(spacing: 0) {
                metric("Income", report.income.money(code), symbol: "arrow.down.left")
                metric("Spent", report.expenses.money(code), symbol: "arrow.up.right")
            }
            if let rate = report.savingsRate {
                VStack(alignment: .leading, spacing: 6) {
                    ShareBar(fraction: rate, color: .white)
                    Text(rate >= 0 ? "Saving \(rate.percentText) of income" : "Spending exceeds income")
                        .font(.caption.weight(.medium))
                        .opacity(0.9)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Theme.brandGradient, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .opacity(0.85)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpendingGroupsCard: View {
    let report: Report

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Where it went", subtitle: "This month by type")
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(report.expenseGroups) { group in
                        Rectangle()
                            .fill(group.group.color.gradient)
                            .frame(width: max(2, proxy.size.width * (group.amount / report.expenses).doubleValue - 2))
                    }
                }
                .clipShape(.capsule)
            }
            .frame(height: 12)

            ForEach(report.expenseGroups) { group in
                HStack {
                    Circle().fill(group.group.color).frame(width: 10, height: 10)
                    Text(group.group.title).font(.subheadline)
                    Spacer()
                    Text(group.amount.money(report.currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text((group.amount / report.expenses).doubleValue.percentText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .card()
    }
}
