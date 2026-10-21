import Foundation
import SwiftData

/// A schedule (mortgage, car loan, insurance, salary…) that creates an `Entry` on every due date.
@Model
final class RecurringPayment {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = 0
    var currencyCode: String = "USD"
    var categoryRaw: String = EntryCategory.otherExpense.rawValue
    var paymentMethodRaw: String = PaymentMethod.bankTransfer.rawValue
    var frequencyRaw: String = Frequency.monthly.rawValue
    var startDate: Date = Date()
    var endDate: Date?
    /// How many occurrences have already been turned into entries.
    var generatedCount: Int = 0
    var isActive: Bool = true
    var note: String = ""
    var createdAt: Date = Date()

    init(
        title: String,
        amount: Decimal,
        currencyCode: String,
        category: EntryCategory,
        paymentMethod: PaymentMethod = .bankTransfer,
        frequency: Frequency = .monthly,
        startDate: Date,
        endDate: Date? = nil,
        note: String = ""
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.categoryRaw = category.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
    }

    var category: EntryCategory {
        get { EntryCategory(rawValue: categoryRaw) ?? .otherExpense }
        set { categoryRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .other }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var displayTitle: String { title.isEmpty ? category.title : title }

    /// The next occurrence that hasn't been recorded yet, or nil when paused or finished.
    var nextDueDate: Date? {
        guard isActive,
              let date = frequency.occurrence(generatedCount, from: startDate)
        else { return nil }
        if let endDate, Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: endDate) {
            return nil
        }
        return date
    }

    var snapshot: RecurringSnapshot {
        RecurringSnapshot(amount: amount, currencyCode: currencyCode, category: category, frequency: frequency, isActive: isActive && nextDueDate != nil)
    }

    func makeEntry(on date: Date) -> Entry {
        Entry(
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            date: date,
            category: category,
            paymentMethod: paymentMethod,
            note: note,
            recurringID: id
        )
    }
}

struct RecurringSnapshot: Hashable {
    var amount: Decimal
    var currencyCode: String
    var category: EntryCategory
    var frequency: Frequency
    var isActive: Bool

    var monthlyAmount: Decimal { amount * frequency.monthlyFactor }
}
