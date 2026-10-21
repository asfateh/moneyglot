import Foundation
import Testing
@testable import Moneyglot

@MainActor
struct InsightsEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let converter = CurrencyConverter(ratesPerUSD: ["USD": 1, "EUR": 0.8])

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Three months of: salary, mortgage, dining and some euro card spending.
    private func entries(salary: Decimal, mortgage: Decimal, septemberDining: Decimal = 300) -> [EntrySnapshot] {
        (7...9).flatMap { month -> [EntrySnapshot] in
            [
                EntrySnapshot(amount: salary, currencyCode: "USD", date: date(2026, month, 1), category: .salary),
                EntrySnapshot(amount: mortgage, currencyCode: "USD", date: date(2026, month, 2), category: .mortgage),
                EntrySnapshot(amount: month == 9 ? septemberDining : 300, currencyCode: "USD", date: date(2026, month, 10), category: .dining),
                EntrySnapshot(amount: 400, currencyCode: "EUR", date: date(2026, month, 12), category: .travel, paymentMethod: .creditCard),
            ]
        }
    }

    private func insights(_ entries: [EntrySnapshot]) -> [Insight] {
        let engine = InsightsEngine(converter: converter, calendar: calendar)
        let snapshot = engine.snapshot(entries: entries, recurring: [], currency: "USD", now: date(2026, 10, 15))
        return engine.insights(for: snapshot)
    }

    @Test func flagsOverspending() {
        let result = insights(entries(salary: 2000, mortgage: 2000))
        #expect(result.contains { $0.id == "overspending" })
        #expect(result.first?.tone == .warning)
    }

    @Test func flagsHeavyDebtAndHousing() {
        let ids = Set(insights(entries(salary: 5000, mortgage: 2000)).map(\.id))
        #expect(ids.contains("debt-load"))
        #expect(ids.contains("housing"))
    }

    @Test func detectsCategorySpike() {
        let ids = insights(entries(salary: 8000, mortgage: 1000, septemberDining: 700)).map(\.id)
        #expect(ids.contains("spike-dining"))
    }

    @Test func estimatesForeignCardFees() {
        let result = insights(entries(salary: 8000, mortgage: 1000))
        let fx = result.first { $0.id == "fx-fees" }
        // 400 EUR = 500 USD per month, 2.5% fee = 12.50 USD
        #expect(fx?.monthlySavings?.rounded(scale: 2) == Decimal(string: "12.5"))
    }

    @Test func readinessNeedsEnoughHistory() {
        let engine = InsightsEngine(converter: converter, calendar: calendar)
        let few = engine.readiness(Array(entries(salary: 1, mortgage: 1).prefix(5)), now: date(2026, 7, 5))
        #expect(!few.isReady)
        let many = engine.readiness(entries(salary: 1, mortgage: 1) + entries(salary: 1, mortgage: 1), now: date(2026, 10, 1))
        #expect(many.isReady)
    }
}

@MainActor
struct CSVExporterTests {
    @Test func escapesSpecialCharacters() {
        #expect(CSVExporter.escape("plain") == "plain")
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
        #expect(CSVExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test func exportsConvertedAmounts() {
        let entry = Entry(title: "Café, Paris", amount: 80, currencyCode: "EUR", date: .now, category: .dining, paymentMethod: .creditCard)
        let csv = CSVExporter.csv(for: [entry], converter: CurrencyConverter(ratesPerUSD: ["USD": 1, "EUR": 0.8]), reportCurrency: "USD")
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[1].contains("\"Café, Paris\""))
        #expect(lines[1].contains(",80,EUR,100,USD,"))
    }

    @Test func parsesLocalizedAmounts() {
        #expect(AmountParser.parse("1,234.50", locale: Locale(identifier: "en_US")) == Decimal(string: "1234.5"))
        #expect(AmountParser.parse("1.234,50", locale: Locale(identifier: "de_DE")) == Decimal(string: "1234.5"))
        #expect(AmountParser.parse("0", locale: Locale(identifier: "en_US")) == nil)
        #expect(AmountParser.parse("abc", locale: Locale(identifier: "en_US")) == nil)
        #expect(AmountParser.parse("1250rupee", locale: Locale(identifier: "en_US")) == nil)
        #expect(AmountParser.parse("1.2.3", locale: Locale(identifier: "en_US")) == nil)
        #expect(AmountParser.parse("١٢٥٠", locale: Locale(identifier: "ar_AE")) == 1250)
    }
}
