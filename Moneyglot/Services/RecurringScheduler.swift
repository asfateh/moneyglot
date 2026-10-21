import Foundation
import SwiftData

/// Turns due occurrences of recurring payments into real entries.
enum RecurringScheduler {
    /// Safety cap so a very old weekly schedule can't create an unbounded number of entries at once.
    static let maxOccurrencesPerRun = 520

    /// Occurrence dates that are due on or before `now`, starting after the ones already generated.
    static func dueDates(
        frequency: Frequency,
        startDate: Date,
        endDate: Date?,
        generatedCount: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let lastDay = endDate.map { calendar.startOfDay(for: $0) }
        var dates: [Date] = []
        var index = generatedCount

        while dates.count < maxOccurrencesPerRun,
              let date = frequency.occurrence(index, from: startDate, calendar: calendar) {
            let day = calendar.startOfDay(for: date)
            if day > today { break }
            if let lastDay, day > lastDay { break }
            dates.append(date)
            index += 1
        }
        return dates
    }

    /// Index of the first occurrence on or after `now`. Used when resuming a paused schedule
    /// so the missed period isn't back-filled.
    static func firstUpcomingIndex(frequency: Frequency, startDate: Date, from index: Int, now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        var index = index
        while index < 10_000,
              let date = frequency.occurrence(index, from: startDate, calendar: calendar),
              calendar.startOfDay(for: date) < today {
            index += 1
        }
        return index
    }

    @discardableResult
    static func materialize(_ payment: RecurringPayment, in context: ModelContext, now: Date = .now) -> Int {
        guard payment.isActive else { return 0 }
        let dates = dueDates(
            frequency: payment.frequency,
            startDate: payment.startDate,
            endDate: payment.endDate,
            generatedCount: payment.generatedCount,
            now: now
        )
        for date in dates {
            context.insert(payment.makeEntry(on: date))
        }
        payment.generatedCount += dates.count
        return dates.count
    }

    /// Creates entries for every active schedule. Safe to call repeatedly.
    @discardableResult
    static func run(in context: ModelContext, now: Date = .now) -> Int {
        let descriptor = FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.isActive })
        guard let payments = try? context.fetch(descriptor) else { return 0 }
        let created = payments.reduce(0) { $0 + materialize($1, in: context, now: now) }
        if created > 0 {
            try? context.save()
        }
        return created
    }
}
