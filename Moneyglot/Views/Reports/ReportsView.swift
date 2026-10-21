import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Environment(CurrencyService.self) private var currency
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @AppStorage(SettingsKey.reportCurrency) private var reportCurrency = CurrencyCatalog.deviceCurrency
    @AppStorage(SettingsKey.favoriteCurrencies) private var favoritesRaw = ""
    @State private var period: ReportPeriod = .month
    @State private var anchor = Date()
    @State private var showingCurrencyPicker = false

    var body: some View {
        let report = ReportBuilder(converter: currency.converter)
            .build(entries.map(\.snapshot), period: period, containing: anchor, currency: reportCurrency)
        let label = period.label(for: report.interval)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    periodNavigator(label: label, interval: report.interval)

                    if report.isEmpty {
                        ContentUnavailableView(
                            "Nothing recorded",
                            systemImage: "chart.bar.xaxis",
                            description: Text("There are no entries for \(label).")
                        )
                        .padding(.top, 40)
                    } else {
                        SummaryGrid(report: report)
                        CashflowCard(report: report, period: period)
                        CategoryBreakdownCard(report: report)
                        if !report.expenseGroups.isEmpty {
                            GroupBreakdownCard(report: report)
                        }
                        if !report.incomeCategories.isEmpty {
                            IncomeBreakdownCard(report: report)
                        }
                        if !report.spendingByCurrency.isEmpty {
                            CurrencyMixCard(report: report)
                        }
                    }

                    footnote(report: report)
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { currencyMenu }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: csvDocument(for: report.interval, label: label),
                        preview: SharePreview("Moneyglot \(label) report")
                    ) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(report.isEmpty)
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selection: $reportCurrency, title: "Report currency")
            }
        }
    }

    private var currencyMenu: some View {
        var codes = FavoriteCurrencies.decode(favoritesRaw)
        if !codes.contains(reportCurrency) { codes.insert(reportCurrency, at: 0) }
        return Menu {
            Picker("Report currency", selection: $reportCurrency) {
                ForEach(codes, id: \.self) { code in
                    Text(CurrencyCatalog.label(for: code)).tag(code)
                }
            }
            Button("More currencies…", systemImage: "globe") { showingCurrencyPicker = true }
        } label: {
            CurrencyChip(code: reportCurrency)
        }
        .accessibilityLabel("Report currency \(CurrencyCatalog.name(for: reportCurrency))")
    }

    private func periodNavigator(label: String, interval: DateInterval) -> some View {
        HStack {
            Button("Previous", systemImage: "chevron.left") { anchor = period.shifted(anchor, by: -1) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(label)
                .font(.title3.weight(.semibold))
                .contentTransition(.numericText())
            Spacer()
            Button("Next", systemImage: "chevron.right") { anchor = period.shifted(anchor, by: 1) }
                .labelStyle(.iconOnly)
                .disabled(interval.end > .now)
        }
        .font(.title3)
        .padding(.horizontal, 4)
        .animation(.snappy, value: label)
    }

    private func footnote(report: Report) -> some View {
        VStack(spacing: 4) {
            Text("Converted to \(reportCurrency) at exchange rates from \(currency.lastUpdated.formatted(date: .abbreviated, time: .omitted)).")
            if !report.unconvertedCurrencies.isEmpty {
                Text("No rate available for \(report.unconvertedCurrencies.joined(separator: ", ")) — those entries are excluded.")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    private func csvDocument(for interval: DateInterval, label: String) -> CSVDocument {
        let inPeriod = entries.filter { $0.date >= interval.start && $0.date < interval.end }
        let filename = "Moneyglot \(label) \(reportCurrency).csv"
        return CSVDocument(
            filename: filename,
            text: CSVExporter.csv(for: inPeriod, converter: currency.converter, reportCurrency: reportCurrency)
        )
    }
}

private struct SummaryGrid: View {
    let report: Report

    var body: some View {
        let code = report.currency
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                MetricTile(title: "Income", value: report.income.money(code), symbol: "arrow.down.left.circle.fill", tint: .green)
                MetricTile(title: "Expenses", value: report.expenses.money(code), symbol: "arrow.up.right.circle.fill", tint: .orange)
            }
            GridRow {
                MetricTile(title: "Net", value: report.net.money(code), symbol: "equal.circle.fill", tint: report.net >= 0 ? .blue : .red)
                MetricTile(title: "Savings rate", value: report.savingsRate?.percentText ?? "—", symbol: "percent", tint: .purple)
            }
        }
    }
}

private struct CashflowCard: View {
    let report: Report
    let period: ReportPeriod

    var body: some View {
        let code = report.currency
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(
                title: period == .month ? "Daily spending" : "Income vs. expenses",
                subtitle: period == .month ? nil : "By month"
            )
            Chart {
                ForEach(report.buckets) { bucket in
                    if period == .month {
                        BarMark(
                            x: .value("Day", bucket.start, unit: .day),
                            y: .value("Spent", bucket.expenses.doubleValue)
                        )
                        .foregroundStyle(Color.orange.gradient)
                        .cornerRadius(3)
                    } else {
                        BarMark(
                            x: .value("Month", bucket.start, unit: .month),
                            y: .value("Amount", bucket.income.doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", "Income"))
                        .position(by: .value("Type", "Income"))
                        .cornerRadius(3)

                        BarMark(
                            x: .value("Month", bucket.start, unit: .month),
                            y: .value("Amount", bucket.expenses.doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", "Expenses"))
                        .position(by: .value("Type", "Expenses"))
                        .cornerRadius(3)
                    }
                }
            }
            .chartForegroundStyleScale(["Income": Color.green, "Expenses": Color.orange])
            .chartLegend(period == .month ? .hidden : .automatic)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.compactMoney(code))
                        }
                    }
                }
            }
            .chartXAxis {
                if period == .month {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                } else {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
            }
            .frame(height: 200)
        }
        .card()
    }
}

private struct CategoryBreakdownCard: View {
    let report: Report

    private struct Slice: Identifiable {
        let id: String
        let title: String
        let amount: Decimal
        let color: Color
    }

    private var slices: [Slice] {
        let top = report.expenseCategories.prefix(6).map {
            Slice(id: $0.category.rawValue, title: $0.category.title, amount: $0.amount, color: $0.category.color)
        }
        let rest = report.expenseCategories.dropFirst(6).reduce(Decimal(0)) { $0 + $1.amount }
        return rest > 0 ? top + [Slice(id: "rest", title: "Everything else", amount: rest, color: .gray)] : top
    }

    var body: some View {
        let code = report.currency
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Spending by category")
            if report.expenses > 0 {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.amount.doubleValue),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color)
                }
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        if let anchor = proxy.plotFrame {
                            let frame = geometry[anchor]
                            VStack(spacing: 2) {
                                Text("Spent").font(.caption).foregroundStyle(.secondary)
                                Text(report.expenses.wholeMoney(code))
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(width: frame.width * 0.55)
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .frame(height: 220)
            }

            ForEach(report.expenseCategories) { total in
                let share = report.expenses > 0 ? (total.amount / report.expenses).doubleValue : 0
                HStack(spacing: 12) {
                    CategoryIcon(category: total.category, size: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(total.category.title).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(total.amount.money(code))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        HStack(spacing: 8) {
                            ShareBar(fraction: share, color: total.category.color)
                            Text(share.percentText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .card()
    }
}

private struct GroupBreakdownCard: View {
    let report: Report

    var body: some View {
        let code = report.currency
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Fixed vs. everyday", subtitle: report.income > 0 ? "Share of income" : nil)
            ForEach(report.expenseGroups) { total in
                HStack {
                    Label(total.group.title, systemImage: total.group.symbol)
                        .foregroundStyle(total.group.color)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(total.amount.money(code))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        if report.income > 0 {
                            Text("\((total.amount / report.income).doubleValue.percentText) of income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .card()
    }
}

private struct IncomeBreakdownCard: View {
    let report: Report

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Income sources")
            ForEach(report.incomeCategories) { total in
                HStack(spacing: 12) {
                    CategoryIcon(category: total.category, size: 30)
                    Text(total.category.title).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(total.amount.money(report.currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
        }
        .card()
    }
}

private struct CurrencyMixCard: View {
    let report: Report

    var body: some View {
        let count = report.spendingByCurrency.count
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(
                title: count == 1 ? "Paid in 1 currency" : "Paid in \(count) currencies",
                subtitle: "Original amounts and their \(report.currency) value"
            )
            ForEach(report.spendingByCurrency) { total in
                let share = report.expenses > 0 ? (total.convertedAmount / report.expenses).doubleValue : 0
                HStack(spacing: 12) {
                    Text(CurrencyCatalog.flag(for: total.code)).font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(total.originalAmount.money(total.code))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Spacer()
                            if total.code != report.currency {
                                Text("≈ " + total.convertedAmount.money(report.currency))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        ShareBar(fraction: share, color: .indigo)
                    }
                }
            }
        }
        .card()
    }
}
