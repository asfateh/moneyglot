import SwiftUI

/// Whether money came in or went out.
enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        }
    }
}

/// High-level buckets used by reports and insights.
enum CategoryGroup: String, CaseIterable, Identifiable {
    case income
    case loans
    case bills
    case everyday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Income"
        case .loans: "Loans & Credit"
        case .bills: "Bills & Insurance"
        case .everyday: "Everyday Spending"
        }
    }

    var symbol: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .loans: "building.columns.fill"
        case .bills: "doc.text.fill"
        case .everyday: "cart.fill"
        }
    }

    var color: Color {
        switch self {
        case .income: .green
        case .loans: .indigo
        case .bills: .orange
        case .everyday: .teal
        }
    }

    /// Expense groups in the order they appear in pickers.
    static let expenseGroups: [CategoryGroup] = [.everyday, .bills, .loans]
}

enum EntryCategory: String, Codable, CaseIterable, Identifiable {
    // Income
    case salary, business, investments, rentalIncome, otherIncome
    // Loans & credit
    case mortgage, carLoan, creditCard, otherLoan
    // Bills & insurance
    case rent, utilities, phoneInternet, insurance, subscriptions
    // Everyday spending
    case groceries, dining, transport, shopping, health, education
    case entertainment, travel, personalCare, giftsDonations, otherExpense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary: "Salary"
        case .business: "Business & Freelance"
        case .investments: "Investments"
        case .rentalIncome: "Rental Income"
        case .otherIncome: "Other Income"
        case .mortgage: "Mortgage"
        case .carLoan: "Car Loan"
        case .creditCard: "Credit Card Payment"
        case .otherLoan: "Other Loan"
        case .rent: "Rent"
        case .utilities: "Bills & Utilities"
        case .phoneInternet: "Phone & Internet"
        case .insurance: "Insurance"
        case .subscriptions: "Subscriptions"
        case .groceries: "Groceries"
        case .dining: "Dining Out"
        case .transport: "Transport & Fuel"
        case .shopping: "Shopping"
        case .health: "Health & Fitness"
        case .education: "Education"
        case .entertainment: "Entertainment"
        case .travel: "Travel"
        case .personalCare: "Personal Care"
        case .giftsDonations: "Gifts & Donations"
        case .otherExpense: "Other"
        }
    }

    /// Compact label for the category grid.
    var shortTitle: String {
        switch self {
        case .business: "Business"
        case .rentalIncome: "Rental"
        case .otherIncome: "Other"
        case .creditCard: "Credit Card"
        case .utilities: "Bills"
        case .phoneInternet: "Phone & Net"
        case .dining: "Dining"
        case .transport: "Transport"
        case .health: "Health"
        case .personalCare: "Self-care"
        case .giftsDonations: "Gifts"
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .salary: "briefcase.fill"
        case .business: "storefront.fill"
        case .investments: "chart.line.uptrend.xyaxis"
        case .rentalIncome: "building.2.fill"
        case .otherIncome: "plus.circle.fill"
        case .mortgage: "house.fill"
        case .carLoan: "car.fill"
        case .creditCard: "creditcard.fill"
        case .otherLoan: "banknote.fill"
        case .rent: "key.fill"
        case .utilities: "bolt.fill"
        case .phoneInternet: "wifi"
        case .insurance: "umbrella.fill"
        case .subscriptions: "repeat.circle.fill"
        case .groceries: "cart.fill"
        case .dining: "fork.knife"
        case .transport: "bus.fill"
        case .shopping: "bag.fill"
        case .health: "heart.fill"
        case .education: "graduationcap.fill"
        case .entertainment: "theatermasks.fill"
        case .travel: "airplane"
        case .personalCare: "sparkles"
        case .giftsDonations: "gift.fill"
        case .otherExpense: "ellipsis.circle.fill"
        }
    }

    var group: CategoryGroup {
        switch self {
        case .salary, .business, .investments, .rentalIncome, .otherIncome: .income
        case .mortgage, .carLoan, .creditCard, .otherLoan: .loans
        case .rent, .utilities, .phoneInternet, .insurance, .subscriptions: .bills
        default: .everyday
        }
    }

    var kind: EntryKind { group == .income ? .income : .expense }

    /// Spending people can usually cut back on quickly.
    var isDiscretionary: Bool {
        switch self {
        case .dining, .shopping, .entertainment, .travel, .personalCare: true
        default: false
        }
    }

    var isHousing: Bool { self == .mortgage || self == .rent }

    /// Distinct, stable hue per category (golden-ratio spacing keeps neighbours apart).
    var color: Color {
        let index = Double(Self.allCases.firstIndex(of: self) ?? 0)
        let hue = (0.47 + index * 0.618_034).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.62, brightness: 0.82)
    }

    static func ordered(for kind: EntryKind) -> [EntryCategory] {
        switch kind {
        case .income:
            allCases.filter { $0.group == .income }
        case .expense:
            CategoryGroup.expenseGroups.flatMap { group in allCases.filter { $0.group == group } }
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash, debitCard, creditCard, bankTransfer, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "Cash"
        case .debitCard: "Debit card"
        case .creditCard: "Credit card"
        case .bankTransfer: "Bank transfer"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.fill"
        case .bankTransfer: "building.columns"
        case .other: "ellipsis.circle"
        }
    }

    var isCard: Bool { self == .debitCard || self == .creditCard }
}

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, quarterly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }

    /// Date of the n-th occurrence (0 = start). Computed from the start date every time so
    /// month-end dates don't drift (Jan 31 → Feb 28 → Mar 31).
    func occurrence(_ index: Int, from start: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly: calendar.date(byAdding: .weekOfYear, value: index, to: start)
        case .biweekly: calendar.date(byAdding: .weekOfYear, value: index * 2, to: start)
        case .monthly: calendar.date(byAdding: .month, value: index, to: start)
        case .quarterly: calendar.date(byAdding: .month, value: index * 3, to: start)
        case .yearly: calendar.date(byAdding: .year, value: index, to: start)
        }
    }

    /// Multiplier that converts one payment into an average monthly amount.
    var monthlyFactor: Decimal {
        switch self {
        case .weekly: Decimal(52) / Decimal(12)
        case .biweekly: Decimal(26) / Decimal(12)
        case .monthly: 1
        case .quarterly: Decimal(1) / Decimal(3)
        case .yearly: Decimal(1) / Decimal(12)
        }
    }
}
