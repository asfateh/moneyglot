import Foundation
import Testing
@testable import Moneyglot

@MainActor
struct RecurringSchedulerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    @Test func monthEndDatesDoNotDrift() {
        let start = date(2026, 1, 31)
        let dates = RecurringScheduler.dueDates(
            frequency: .monthly, startDate: start, endDate: nil, generatedCount: 0,
            now: date(2026, 4, 30), calendar: calendar
        )
        let days = dates.map { calendar.component(.day, from: $0) }
        #expect(days == [31, 28, 31, 30])
    }

    @Test func onlyUngeneratedOccurrencesAreDue() {
        let dates = RecurringScheduler.dueDates(
            frequency: .monthly, startDate: date(2026, 1, 1), endDate: nil, generatedCount: 2,
            now: date(2026, 4, 15), calendar: calendar
        )
        #expect(dates == [date(2026, 3, 1), date(2026, 4, 1)])
    }

    @Test func endDateStopsTheSchedule() {
        let dates = RecurringScheduler.dueDates(
            frequency: .weekly, startDate: date(2026, 1, 1), endDate: date(2026, 1, 20), generatedCount: 0,
            now: date(2026, 6, 1), calendar: calendar
        )
        #expect(dates.count == 3) // Jan 1, 8, 15
    }

    @Test func futureStartHasNothingDue() {
        let dates = RecurringScheduler.dueDates(
            frequency: .yearly, startDate: date(2027, 1, 1), endDate: nil, generatedCount: 0,
            now: date(2026, 6, 1), calendar: calendar
        )
        #expect(dates.isEmpty)
    }

    @Test func resumingSkipsMissedPeriods() {
        let index = RecurringScheduler.firstUpcomingIndex(
            frequency: .monthly, startDate: date(2026, 1, 10), from: 1,
            now: date(2026, 5, 20), calendar: calendar
        )
        #expect(index == 5) // June 10 is the next occurrence
    }

    @Test func frequenciesNormaliseToMonthly() {
        #expect((Frequency.yearly.monthlyFactor * 1200).rounded(scale: 6) == 100)
        #expect(Frequency.monthly.monthlyFactor == 1)
        #expect((Frequency.weekly.monthlyFactor * 12).rounded(scale: 6) == 52)
    }
}
