import Foundation

struct Insight: Identifiable, Hashable {
    enum Tone: Int, Comparable {
        case warning, tip, positive
        static func < (lhs: Tone, rhs: Tone) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let tone: Tone
    let symbol: String
    let title: String
    let message: String
    var monthlySavings: Decimal?
}

/// How much history exists. Insights need enough data to be meaningful.
struct DataReadiness {
    static let requiredEntries = 20
    static let requiredDays = 28

    let entryCount: Int
    let daysCovered: Int

    var isReady: Bool { entryCount >= Self.requiredEntries && daysCovered >= Self.requiredDays }

    var progress: Double {
        let entries = min(Double(entryCount) / Double(Self.requiredEntries), 1)
        let days = min(Double(daysCovered) / Double(Self.requiredDays), 1)
        return (entries + days) / 2
    }

    var remainingDescription: String {
        let entriesLeft = max(0, Self.requiredEntries - entryCount)
        let daysLeft = max(0, Self.requiredDays - daysCovered)
        var parts: [String] = []
        if entriesLeft > 0 { parts.append("\(entriesLeft) more \(entriesLeft == 1 ? "entry" : "entries")") }
        if daysLeft > 0 { parts.append("\(daysLeft) more \(daysLeft == 1 ? "day" : "days") of history") }
        guard !parts.isEmpty else { return "You have enough data for personalized insights." }
        return "Add \(parts.joined(separator: " and ")) to unlock personalized insights."
    }
}

/// Monthly averages of a person's finances in one currency — the input for both the rule-based
/// insights and the on-device AI coach.
struct FinancialSnapshot {
    let currency: String
    let months: [Report]
    let averageIncome: Decimal
    let averageExpenses: Decimal
    let averageByCategory: [EntryCategory: Decimal]
    let averageByGroup: [CategoryGroup: Decimal]
    /// Averages of the months before the latest one, used to spot spikes.
    let earlierAverageByCategory: [EntryCategory: Decimal]
    let earlierAverageExpenses: Decimal?
    let foreignSpendingPerMonth: Decimal
    let foreignCardSpendingPerMonth: Decimal
    let foreignCurrencies: [String]
    let recurringMonthlyExpenses: Decimal

    var monthsAnalyzed: Int { months.count }
    var latestMonth: Report? { months.count >= 2 ? months.last : nil }
    var net: Decimal { averageIncome - averageExpenses }

    var savingsRate: Double? {
        guard averageIncome > 0 else { return nil }
        return (net / averageIncome).doubleValue
    }

    var periodLabel: String {
        guard let first = months.first, let last = months.last else { return "" }
        if months.count == 1 { return ReportPeriod.month.label(for: first.interval) }
        return "\(first.interval.start.formatted(.dateTime.month(.abbreviated))) – \(last.interval.start.formatted(.dateTime.month(.abbreviated).year()))"
    }

    /// Compact, numbers-only description of the person's finances for the language model.
    func promptText(insights: [Insight]) -> String {
        var lines = [
            "Monthly averages in \(currency) over \(monthsAnalyzed) month\(monthsAnalyzed == 1 ? "" : "s") (\(periodLabel)):",
            "Income: \(averageIncome.wholeMoney(currency))",
            "Expenses: \(averageExpenses.wholeMoney(currency))",
        ]
        if let savingsRate { lines.append("Savings rate: \(savingsRate.percentText)") }
        lines.append("Spending by category:")
        for (category, amount) in averageByCategory.sorted(by: { $0.value > $1.value }).prefix(12) {
            lines.append("- \(category.title) [\(category.group.title)]: \(amount.wholeMoney(currency))")
        }
        if recurringMonthlyExpenses > 0 {
            lines.append("Fixed repeating payments: \(recurringMonthlyExpenses.wholeMoney(currency)) per month")
        }
        if foreignSpendingPerMonth > 0 {
            lines.append("Spending in other currencies (\(foreignCurrencies.joined(separator: ", "))): \(foreignSpendingPerMonth.wholeMoney(currency)) per month, \(foreignCardSpendingPerMonth.wholeMoney(currency)) of it by card")
        }
        if !insights.isEmpty {
            lines.append("Observations:")
            lines += insights.prefix(6).map { "- \($0.title)" }
        }
        return lines.joined(separator: "\n")
    }
}

struct InsightsEngine {
    var converter: CurrencyConverter
    var calendar: Calendar = .current

    func readiness(_ entries: [EntrySnapshot], now: Date = .now) -> DataReadiness {
        guard let earliest = entries.map(\.date).min() else { return DataReadiness(entryCount: 0, daysCovered: 0) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: earliest), to: calendar.startOfDay(for: now)).day ?? 0
        return DataReadiness(entryCount: entries.count, daysCovered: max(days, 0))
    }

    func snapshot(entries: [EntrySnapshot], recurring: [RecurringSnapshot], currency: String, now: Date = .now) -> FinancialSnapshot {
        let builder = ReportBuilder(converter: converter, calendar: calendar)
        var months = builder.previousMonths(entries, count: 3, before: now, currency: currency).filter { !$0.isEmpty }
        if months.isEmpty {
            let current = builder.build(entries, period: .month, containing: now, currency: currency)
            if !current.isEmpty { months = [current] }
        }

        let count = Decimal(max(months.count, 1))
        var byCategory: [EntryCategory: Decimal] = [:]
        var byGroup: [CategoryGroup: Decimal] = [:]
        for month in months {
            for total in month.expenseCategories { byCategory[total.category, default: 0] += total.amount }
            for total in month.expenseGroups { byGroup[total.group, default: 0] += total.amount }
        }

        var earlierByCategory: [EntryCategory: Decimal] = [:]
        var earlierExpenses: Decimal?
        if months.count >= 2 {
            let earlier = months.dropLast()
            let earlierCount = Decimal(earlier.count)
            for month in earlier {
                for total in month.expenseCategories { earlierByCategory[total.category, default: 0] += total.amount / earlierCount }
            }
            earlierExpenses = earlier.reduce(Decimal(0)) { $0 + $1.expenses } / earlierCount
        }

        var foreign: Decimal = 0
        var foreignCard: Decimal = 0
        var foreignCodes = Set<String>()
        if let start = months.first?.interval.start, let end = months.last?.interval.end {
            for entry in entries where entry.kind == .expense && entry.currencyCode != currency && entry.date >= start && entry.date < end {
                guard let value = converter.convert(entry.amount, from: entry.currencyCode, to: currency) else { continue }
                foreign += value
                if entry.paymentMethod.isCard { foreignCard += value }
                foreignCodes.insert(entry.currencyCode)
            }
        }

        let recurringMonthly = recurring
            .filter { $0.isActive && $0.category.kind == .expense }
            .compactMap { converter.convert($0.monthlyAmount, from: $0.currencyCode, to: currency) }
            .reduce(Decimal(0), +)

        return FinancialSnapshot(
            currency: currency,
            months: months,
            averageIncome: months.reduce(Decimal(0)) { $0 + $1.income } / count,
            averageExpenses: months.reduce(Decimal(0)) { $0 + $1.expenses } / count,
            averageByCategory: byCategory.mapValues { $0 / count },
            averageByGroup: byGroup.mapValues { $0 / count },
            earlierAverageByCategory: earlierByCategory,
            earlierAverageExpenses: earlierExpenses,
            foreignSpendingPerMonth: foreign / count,
            foreignCardSpendingPerMonth: foreignCard / count,
            foreignCurrencies: foreignCodes.sorted(),
            recurringMonthlyExpenses: recurringMonthly
        )
    }

    func insights(for s: FinancialSnapshot) -> [Insight] {
        guard s.monthsAnalyzed > 0 else { return [] }
        let c = s.currency
        let income = s.averageIncome
        let expenses = s.averageExpenses
        let span = s.monthsAnalyzed == 1 ? "this month" : "over the last \(s.monthsAnalyzed) months"
        var result: [Insight] = []

        func share(_ part: Decimal, of whole: Decimal) -> Double { whole > 0 ? (part / whole).doubleValue : 0 }

        if income == 0 && expenses > 0 {
            result.append(Insight(
                id: "add-income", tone: .tip, symbol: "plus.circle.fill",
                title: "Add your income",
                message: "Record your salary or other income so Moneyglot can measure your savings rate and how much of it goes to loans and bills."
            ))
        }

        if income > 0 {
            if expenses > income {
                result.append(Insight(
                    id: "overspending", tone: .warning, symbol: "exclamationmark.triangle.fill",
                    title: "You're spending more than you earn",
                    message: "\(span.capitalizedFirst) you spent about \((expenses - income).wholeMoney(c)) more than you earned each month. The suggestions below can help close the gap.",
                    monthlySavings: expenses - income
                ))
            } else if let rate = s.savingsRate {
                if rate < 0.10 {
                    let gap = income * 10 / 100 - s.net
                    result.append(Insight(
                        id: "low-savings", tone: .warning, symbol: "arrow.down.right.circle.fill",
                        title: "Your savings rate is \(rate.percentText)",
                        message: "Many planners suggest saving 10–20% of income. Freeing up about \(gap.wholeMoney(c)) a month would get you to 10%.",
                        monthlySavings: gap
                    ))
                } else if rate >= 0.20 {
                    result.append(Insight(
                        id: "great-savings", tone: .positive, symbol: "star.circle.fill",
                        title: "Great savings rate: \(rate.percentText)",
                        message: "You're keeping about \(s.net.wholeMoney(c)) a month — above the 20% many planners recommend."
                    ))
                }
            }

            let loans = s.averageByGroup[.loans] ?? 0
            if share(loans, of: income) > 0.36 {
                result.append(Insight(
                    id: "debt-load", tone: .warning, symbol: "building.columns.fill",
                    title: "Debt payments take \(share(loans, of: income).percentText) of income",
                    message: "Mortgage, loan and card payments total \(loans.wholeMoney(c)) a month. Lenders like this below 36%. Avoid new borrowing and put any extra toward the highest-interest debt first."
                ))
            }

            let housing = (s.averageByCategory[.mortgage] ?? 0) + (s.averageByCategory[.rent] ?? 0)
            if share(housing, of: income) > 0.30 {
                result.append(Insight(
                    id: "housing", tone: .tip, symbol: "house.fill",
                    title: "Housing is \(share(housing, of: income).percentText) of income",
                    message: "Mortgage and rent cost \(housing.wholeMoney(c)) a month, above the common 30% guideline. Check refinancing options or renegotiate at your next renewal."
                ))
            }
        }

        if let latest = s.latestMonth, !s.earlierAverageByCategory.isEmpty {
            let monthName = latest.interval.start.formatted(.dateTime.month(.wide))
            let spikes = latest.expenseCategories
                .compactMap { total -> (category: EntryCategory, now: Decimal, before: Decimal)? in
                    guard total.category.group != .loans,
                          let before = s.earlierAverageByCategory[total.category], before > 0
                    else { return nil }
                    let increase = total.amount - before
                    guard increase / before >= 0.3, increase >= max(expenses * 3 / 100, 1) else { return nil }
                    return (total.category, total.amount, before)
                }
                .sorted { ($0.now - $0.before) > ($1.now - $1.before) }
                .prefix(2)
            for spike in spikes {
                result.append(Insight(
                    id: "spike-\(spike.category.rawValue)", tone: .warning, symbol: "chart.line.uptrend.xyaxis",
                    title: "\(spike.category.title) up \(share(spike.now - spike.before, of: spike.before).percentText)",
                    message: "You spent \(spike.now.wholeMoney(c)) on \(spike.category.title.lowercased()) in \(monthName), compared with about \(spike.before.wholeMoney(c)) in earlier months.",
                    monthlySavings: spike.now - spike.before
                ))
            }
        }

        if expenses > 0,
           let top = s.averageByCategory.filter({ $0.key.isDiscretionary }).max(by: { $0.value < $1.value }),
           share(top.value, of: expenses) >= 0.08 {
            let saving = top.value * 15 / 100
            result.append(Insight(
                id: "trim-\(top.key.rawValue)", tone: .tip, symbol: top.key.symbol,
                title: "Trim \(top.key.title.lowercased()) by 15%",
                message: "\(top.key.title) averages \(top.value.wholeMoney(c)) a month (\(share(top.value, of: expenses).percentText) of spending). A weekly limit that cuts 15% saves about \((saving * 12).wholeMoney(c)) a year.",
                monthlySavings: saving
            ))
        }

        let subscriptions = s.averageByCategory[.subscriptions] ?? 0
        if subscriptions > 0 {
            result.append(Insight(
                id: "subscriptions", tone: .tip, symbol: "repeat.circle.fill",
                title: "Review your subscriptions",
                message: "Subscriptions cost about \(subscriptions.wholeMoney(c)) a month (\((subscriptions * 12).wholeMoney(c)) a year). Cancelling the ones you rarely use often trims a quarter of that.",
                monthlySavings: subscriptions / 4
            ))
        }

        let card = s.averageByCategory[.creditCard] ?? 0
        if share(card, of: expenses) >= 0.15 {
            result.append(Insight(
                id: "credit-card", tone: .tip, symbol: "creditcard.fill",
                title: "Pay cards in full each month",
                message: "Credit card payments average \(card.wholeMoney(c)) a month. Paying the full statement balance avoids interest that often exceeds 20% a year."
            ))
        }

        let insurance = s.averageByCategory[.insurance] ?? 0
        if income > 0, share(insurance, of: income) >= 0.08 {
            result.append(Insight(
                id: "insurance", tone: .tip, symbol: "umbrella.fill",
                title: "Shop around for insurance",
                message: "Insurance costs \(insurance.wholeMoney(c)) a month (\(share(insurance, of: income).percentText) of income). Comparing quotes or bundling policies at renewal commonly saves 10–15%.",
                monthlySavings: insurance / 10
            ))
        }

        let fxFee = s.foreignCardSpendingPerMonth * 25 / 1000
        if fxFee >= 1 {
            result.append(Insight(
                id: "fx-fees", tone: .tip, symbol: "globe",
                title: "Watch foreign transaction fees",
                message: "You spend about \(s.foreignCardSpendingPerMonth.wholeMoney(c)) a month by card in \(s.foreignCurrencies.joined(separator: ", ")). Cards often add ~2.5% to foreign purchases — around \(fxFee.wholeMoney(c)) a month. A no-foreign-fee card avoids that.",
                monthlySavings: fxFee
            ))
        }

        if income > 0, share(s.recurringMonthlyExpenses, of: income) >= 0.5 {
            result.append(Insight(
                id: "fixed-costs", tone: .tip, symbol: "lock.fill",
                title: "Fixed costs use \(share(s.recurringMonthlyExpenses, of: income).percentText) of income",
                message: "Your repeating payments total \(s.recurringMonthlyExpenses.wholeMoney(c)) a month, leaving less room for surprises. Review them one by one — small cuts repeat every month."
            ))
        }

        if let latest = s.latestMonth, let earlier = s.earlierAverageExpenses, earlier > 0, latest.expenses <= earlier * 9 / 10 {
            result.append(Insight(
                id: "spending-down", tone: .positive, symbol: "arrow.down.circle.fill",
                title: "Spending is down",
                message: "You spent \(latest.expenses.wholeMoney(c)) in \(latest.interval.start.formatted(.dateTime.month(.wide))), \(share(earlier - latest.expenses, of: earlier).percentText) less than your earlier average. Keep it up!"
            ))
        }

        return result.sorted {
            if $0.tone != $1.tone { return $0.tone < $1.tone }
            return ($0.monthlySavings ?? 0) > ($1.monthlySavings ?? 0)
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
