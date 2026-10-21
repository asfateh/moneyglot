import Foundation
import Testing
@testable import Moneyglot

@MainActor
struct ReportBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let converter = CurrencyConverter(ratesPerUSD: ["USD": 1, "CAD": 1.25, "EUR": 0.8])

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func quarterIntervalCoversThreeMonths() {
        let interval = ReportPeriod.quarter.interval(containing: date(2026, 11, 15), calendar: calendar)
        #expect(interval.start == calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        #expect(interval.end == calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        #expect(ReportPeriod.quarter.label(for: interval, calendar: calendar) == "Q4 2026")
    }

    @Test func totalsAreConvertedToReportCurrency() {
        let entries = [
            EntrySnapshot(amount: 1000, currencyCode: "USD", date: date(2026, 10, 1), category: .salary),
            EntrySnapshot(amount: 125, currencyCode: "CAD", date: date(2026, 10, 5), category: .groceries),
            EntrySnapshot(amount: 80, currencyCode: "EUR", date: date(2026, 10, 9), category: .dining),
            EntrySnapshot(amount: 999, currencyCode: "USD", date: date(2026, 9, 30), category: .dining), // outside period
        ]
        let report = ReportBuilder(converter: converter, calendar: calendar)
            .build(entries, period: .month, containing: date(2026, 10, 15), currency: "USD")

        #expect(report.entryCount == 3)
        #expect(report.income == 1000)
        #expect(report.expenses.rounded(scale: 2) == 200) // 100 (from CAD) + 100 (from EUR)
        #expect(report.net.rounded(scale: 2) == 800)
        #expect(report.savingsRate.map { ($0 * 100).rounded() } == 80)
        #expect(report.buckets.count == 31)
        #expect(Set(report.spendingByCurrency.map(\.code)) == ["CAD", "EUR"])
    }

    @Test func categoriesAreSortedByAmount() {
        let entries = [
            EntrySnapshot(amount: 50, currencyCode: "USD", date: date(2026, 3, 2), category: .dining),
            EntrySnapshot(amount: 1500, currencyCode: "USD", date: date(2026, 3, 1), category: .mortgage),
            EntrySnapshot(amount: 70, currencyCode: "USD", date: date(2026, 3, 4), category: .dining),
        ]
        let report = ReportBuilder(converter: converter, calendar: calendar)
            .build(entries, period: .year, containing: date(2026, 6, 1), currency: "USD")

        #expect(report.expenseCategories.map(\.category) == [.mortgage, .dining])
        #expect(report.expenseCategories.last?.count == 2)
        #expect(report.expenses(in: .loans) == 1500)
        #expect(report.buckets.count == 12)
    }

    @Test func entriesWithoutRatesAreReported() {
        let entries = [EntrySnapshot(amount: 10, currencyCode: "XYZ", date: date(2026, 1, 3), category: .other)]
        let report = ReportBuilder(converter: converter, calendar: calendar)
            .build(entries, period: .month, containing: date(2026, 1, 3), currency: "USD")
        #expect(report.isEmpty)
        #expect(report.unconvertedCurrencies == ["XYZ"])
    }
}

private extension EntryCategory {
    static let other = EntryCategory.otherExpense
}

@MainActor
struct CurrencyConverterTests {
    let converter = CurrencyConverter(ratesPerUSD: ["USD": 1, "CAD": 1.25, "EUR": 0.8])

    @Test func sameCurrencyIsUnchanged() {
        #expect(converter.convert(42, from: "CAD", to: "CAD") == 42)
    }

    @Test func crossRateGoesThroughBase() {
        // 1 EUR = 1.25 USD = 1.5625 CAD
        let value = converter.convert(100, from: "EUR", to: "CAD")
        #expect(value?.rounded(scale: 4) == Decimal(string: "156.25"))
    }

    @Test func unknownCurrencyReturnsNil() {
        #expect(converter.convert(1, from: "USD", to: "ABC") == nil)
    }
}
