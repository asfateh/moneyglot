import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case month, quarter, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "Month"
        case .quarter: "Quarter"
        case .year: "Year"
        }
    }

    /// Chart granularity inside the period.
    var bucket: Calendar.Component { self == .month ? .day : .month }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        case .quarter:
            // Calendar's own `.quarter` support is unreliable, so derive it from the month.
            let components = calendar.dateComponents([.year, .month], from: date)
            let firstMonth = ((components.month ?? 1) - 1) / 3 * 3 + 1
            guard let start = calendar.date(from: DateComponents(year: components.year, month: firstMonth, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 3, to: start)
            else { return DateInterval(start: date, duration: 0) }
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 0)
        }
    }

    func shifted(_ date: Date, by value: Int, calendar: Calendar = .current) -> Date {
        let shifted: Date? = switch self {
        case .month: calendar.date(byAdding: .month, value: value, to: date)
        case .quarter: calendar.date(byAdding: .month, value: value * 3, to: date)
        case .year: calendar.date(byAdding: .year, value: value, to: date)
        }
        return shifted ?? date
    }

    func label(for interval: DateInterval, calendar: Calendar = .current) -> String {
        switch self {
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let month = calendar.component(.month, from: interval.start)
            let year = calendar.component(.year, from: interval.start)
            return "Q\((month - 1) / 3 + 1) \(year)"
        case .year:
            return interval.start.formatted(.dateTime.year())
        }
    }
}

struct CategoryTotal: Identifiable, Hashable {
    let category: EntryCategory
    let amount: Decimal
    let count: Int
    var id: EntryCategory { category }
}

struct GroupTotal: Identifiable, Hashable {
    let group: CategoryGroup
    let amount: Decimal
    var id: CategoryGroup { group }
}

struct CurrencyTotal: Identifiable, Hashable {
    let code: String
    let originalAmount: Decimal
    let convertedAmount: Decimal
    var id: String { code }
}

struct ReportBucket: Identifiable, Hashable {
    let start: Date
    var income: Decimal = 0
    var expenses: Decimal = 0
    var id: Date { start }
}

/// Everything shown on the Reports screen for one period, converted to one currency.
struct Report {
    let interval: DateInterval
    let currency: String
    var income: Decimal = 0
    var expenses: Decimal = 0
    var expenseCategories: [CategoryTotal] = []
    var incomeCategories: [CategoryTotal] = []
    var expenseGroups: [GroupTotal] = []
    var buckets: [ReportBucket] = []
    /// Expenses split by the currency they were originally paid in.
    var spendingByCurrency: [CurrencyTotal] = []
    var entryCount = 0
    /// Currencies we had no exchange rate for (their entries are left out of totals).
    var unconvertedCurrencies: [String] = []

    var net: Decimal { income - expenses }
    var isEmpty: Bool { entryCount == 0 }

    var savingsRate: Double? {
        guard income > 0 else { return nil }
        return (net / income).doubleValue
    }

    func expenses(in category: EntryCategory) -> Decimal {
        expenseCategories.first { $0.category == category }?.amount ?? 0
    }

    func expenses(in group: CategoryGroup) -> Decimal {
        expenseGroups.first { $0.group == group }?.amount ?? 0
    }
}

struct ReportBuilder {
    var converter: CurrencyConverter
    var calendar: Calendar = .current

    func build(_ entries: [EntrySnapshot], period: ReportPeriod, containing date: Date, currency: String) -> Report {
        build(entries, interval: period.interval(containing: date, calendar: calendar), bucket: period.bucket, currency: currency)
    }

    func build(_ entries: [EntrySnapshot], interval: DateInterval, bucket: Calendar.Component = .month, currency: String) -> Report {
        var report = Report(interval: interval, currency: currency)
        var expenseByCategory: [EntryCategory: (amount: Decimal, count: Int)] = [:]
        var incomeByCategory: [EntryCategory: (amount: Decimal, count: Int)] = [:]
        var byGroup: [CategoryGroup: Decimal] = [:]
        var byCurrency: [String: (original: Decimal, converted: Decimal)] = [:]
        var bucketTotals: [Date: ReportBucket] = [:]
        var missing = Set<String>()

        for entry in entries where entry.date >= interval.start && entry.date < interval.end {
            guard let value = converter.convert(entry.amount, from: entry.currencyCode, to: currency) else {
                missing.insert(entry.currencyCode)
                continue
            }
            report.entryCount += 1
            let bucketStart = calendar.dateInterval(of: bucket, for: entry.date)?.start ?? entry.date

            switch entry.kind {
            case .income:
                report.income += value
                incomeByCategory[entry.category, default: (0, 0)].amount += value
                incomeByCategory[entry.category, default: (0, 0)].count += 1
                bucketTotals[bucketStart, default: ReportBucket(start: bucketStart)].income += value
            case .expense:
                report.expenses += value
                expenseByCategory[entry.category, default: (0, 0)].amount += value
                expenseByCategory[entry.category, default: (0, 0)].count += 1
                byGroup[entry.category.group, default: 0] += value
                byCurrency[entry.currencyCode, default: (0, 0)].original += entry.amount
                byCurrency[entry.currencyCode, default: (0, 0)].converted += value
                bucketTotals[bucketStart, default: ReportBucket(start: bucketStart)].expenses += value
            }
        }

        report.expenseCategories = expenseByCategory
            .map { CategoryTotal(category: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
        report.incomeCategories = incomeByCategory
            .map { CategoryTotal(category: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
        report.expenseGroups = CategoryGroup.expenseGroups
            .compactMap { group in byGroup[group].map { GroupTotal(group: group, amount: $0) } }
            .sorted { $0.amount > $1.amount }
        report.spendingByCurrency = byCurrency
            .map { CurrencyTotal(code: $0.key, originalAmount: $0.value.original, convertedAmount: $0.value.converted) }
            .sorted { $0.convertedAmount > $1.convertedAmount }
        report.unconvertedCurrencies = missing.sorted()

        // Include empty buckets so charts show quiet days/months too.
        var cursor = interval.start
        while cursor < interval.end {
            report.buckets.append(bucketTotals[cursor] ?? ReportBucket(start: cursor))
            guard let next = calendar.date(byAdding: bucket, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return report
    }

    /// Reports for each of the `count` whole months before the month containing `date`, oldest first.
    func previousMonths(_ entries: [EntrySnapshot], count: Int, before date: Date, currency: String) -> [Report] {
        (1...max(count, 1)).reversed().map { offset in
            let monthDate = ReportPeriod.month.shifted(date, by: -offset, calendar: calendar)
            return build(entries, period: .month, containing: monthDate, currency: currency)
        }
    }
}
