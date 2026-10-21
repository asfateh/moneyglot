#if DEBUG
import Foundation
import SwiftData

/// Realistic, reproducible multi-currency demo data for development and App Store screenshots.
/// Persona: lives in the US (USD), owns a rented-out condo in Toronto (CAD), freelances for a
/// European client (EUR) and took a summer trip to Paris and London (EUR, GBP).
enum SampleData {
    static func load(into context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        clear(context)

        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let start = calendar.date(byAdding: .month, value: -6, to: thisMonth)
        else { return }

        /// A date in month `offset` (0 = six months ago, 6 = this month), or nil if it's in the future.
        func day(_ offset: Int, _ day: Int) -> Date? {
            guard let month = calendar.date(byAdding: .month, value: offset, to: start) else { return nil }
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = day
            components.hour = 12
            guard let date = calendar.date(from: components), date <= now else { return nil }
            return date
        }

        let schedules: [RecurringPayment] = [
            RecurringPayment(title: "Paycheck", amount: 3450, currencyCode: "USD", category: .salary, frequency: .biweekly, startDate: day(0, 3)!),
            RecurringPayment(title: "Toronto condo rent", amount: 2300, currencyCode: "CAD", category: .rentalIncome, startDate: day(0, 1)!),
            RecurringPayment(title: "Home mortgage", amount: 2450, currencyCode: "USD", category: .mortgage, startDate: day(0, 1)!),
            RecurringPayment(title: "Condo mortgage (TD)", amount: 1580, currencyCode: "CAD", category: .mortgage, startDate: day(0, 3)!),
            RecurringPayment(title: "Car loan", amount: 465, currencyCode: "USD", category: .carLoan, startDate: day(0, 12)!),
            RecurringPayment(title: "Car insurance", amount: 142, currencyCode: "USD", category: .insurance, paymentMethod: .creditCard, startDate: day(0, 6)!),
            RecurringPayment(title: "Condo insurance", amount: 48, currencyCode: "CAD", category: .insurance, startDate: day(0, 8)!),
            RecurringPayment(title: "Life insurance", amount: 54, currencyCode: "USD", category: .insurance, startDate: day(0, 10)!),
            RecurringPayment(title: "Electricity & gas", amount: 185, currencyCode: "USD", category: .utilities, startDate: day(0, 18)!),
            RecurringPayment(title: "Phone & internet", amount: 120, currencyCode: "USD", category: .phoneInternet, paymentMethod: .creditCard, startDate: day(0, 14)!),
            RecurringPayment(title: "Streaming bundle", amount: Decimal(string: "24.99")!, currencyCode: "USD", category: .subscriptions, paymentMethod: .creditCard, startDate: day(0, 9)!),
            RecurringPayment(title: "Music", amount: Decimal(string: "11.99")!, currencyCode: "USD", category: .subscriptions, paymentMethod: .creditCard, startDate: day(0, 9)!),
            RecurringPayment(title: "Cloud storage", amount: Decimal(string: "2.99")!, currencyCode: "USD", category: .subscriptions, paymentMethod: .creditCard, startDate: day(0, 11)!),
            RecurringPayment(title: "Gym membership", amount: 49, currencyCode: "USD", category: .health, paymentMethod: .creditCard, startDate: day(0, 2)!),
        ]
        schedules.forEach { context.insert($0) }

        var rng = SeededGenerator(seed: 2026)
        func random(_ range: ClosedRange<Double>) -> Decimal {
            Decimal(string: String(format: "%.2f", Double.random(in: range, using: &rng))) ?? 0
        }
        func randomDay() -> Int { Int.random(in: 1...28, using: &rng) }
        func pick(_ options: [String]) -> String { options.randomElement(using: &rng) ?? options[0] }
        func add(_ title: String, _ amount: Decimal, _ currency: String, _ category: EntryCategory, _ method: PaymentMethod, _ date: Date?) {
            guard let date else { return }
            context.insert(Entry(title: title, amount: amount, currencyCode: currency, date: date, category: category, paymentMethod: method))
        }

        for month in 0...6 {
            for week in 0..<4 {
                add(pick(["Trader Joe's", "Costco", "Whole Foods", "Safeway"]), random(85...165), "USD", .groceries, week.isMultiple(of: 2) ? .creditCard : .debitCard, day(month, 2 + week * 7))
            }
            // September (month 5) has a dining spike for the insights demo.
            let diningCount = month == 5 ? 13 : Int.random(in: 5...7, using: &rng)
            for _ in 0..<diningCount {
                add(pick(["Sushi Ko", "Blue Bottle", "Taco Loco", "Pizzeria Uno", "Thai Basil", "Shake Shack"]), random(18...68), "USD", .dining, .creditCard, day(month, randomDay()))
            }
            for _ in 0..<4 {
                add(pick(["Shell", "Chevron", "Uber"]), random(42...70), "USD", .transport, .creditCard, day(month, randomDay()))
            }
            for _ in 0..<3 {
                add(pick(["Target", "Amazon", "Uniqlo", "Apple Store", "IKEA"]), random(25...160), "USD", .shopping, .creditCard, day(month, randomDay()))
            }
            add(pick(["Movie night", "Concert tickets", "Bowling"]), random(24...85), "USD", .entertainment, .creditCard, day(month, randomDay()))
            add("Haircut", random(35...55), "USD", .personalCare, .debitCard, day(month, randomDay()))
            add("Pharmacy", random(12...38), "USD", .health, .debitCard, day(month, randomDay()))
            if month.isMultiple(of: 2) {
                add("Client project — Studio Berlin", random(850...1400), "EUR", .business, .bankTransfer, day(month, 16))
            }
        }

        // Summer trip to Paris & London (month 3).
        add("Hotel Le Marais", 780, "EUR", .travel, .creditCard, day(3, 8))
        add("Eurostar to London", 96, "EUR", .travel, .creditCard, day(3, 12))
        add("Hotel in Shoreditch", 420, "GBP", .travel, .creditCard, day(3, 12))
        for date in [9, 10, 11] {
            add(pick(["Café de Flore", "Bistro Paul", "Boulangerie"]), random(28...85), "EUR", .dining, .creditCard, day(3, date))
        }
        for date in [13, 14] {
            add(pick(["Dishoom", "Borough Market", "Pub lunch"]), random(25...60), "GBP", .dining, .creditCard, day(3, date))
        }
        add("Musée d'Orsay", 32, "EUR", .entertainment, .creditCard, day(3, 10))
        add("Oyster card", 40, "GBP", .transport, .creditCard, day(3, 13))

        // Visit to the Toronto condo (month 5).
        add("Condo repairs", 380, "CAD", .otherExpense, .creditCard, day(5, 20))
        add("Pai Northern Thai", 74, "CAD", .dining, .creditCard, day(5, 21))
        add("UP Express", Decimal(string: "24.70")!, "CAD", .transport, .creditCard, day(5, 22))

        RecurringScheduler.run(in: context, now: now)
        try? context.save()

        let defaults = UserDefaults.standard
        defaults.set("USD", forKey: SettingsKey.reportCurrency)
        defaults.set("USD,CAD,EUR,GBP", forKey: SettingsKey.favoriteCurrencies)
        defaults.set("USD", forKey: SettingsKey.lastEntryCurrency)
    }

    static func clear(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<Entry>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<RecurringPayment>()))?.forEach { context.delete($0) }
        try? context.save()
    }
}

/// SplitMix64 — deterministic so screenshots look the same every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
