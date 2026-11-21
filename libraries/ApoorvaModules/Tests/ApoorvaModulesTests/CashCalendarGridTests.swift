import Testing
import Foundation
@testable import ApoorvaModules

struct CashCalendarGridTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func novemberStartsOnASundayAndHasThirtyDays() {
        // 1 Nov 2026 is a Sunday; with Sunday first there is no padding.
        let sunday = calendar(firstWeekday: 1)
        let cells = CashCalendarGrid.cells(for: date(2026, 11, 15, in: sunday), calendar: sunday)
        #expect(cells.count == 30)
        #expect(cells.first! != nil)

        // With Monday first, the 1st (a Sunday) sits in the last column: six leading blanks.
        let monday = calendar(firstWeekday: 2)
        let padded = CashCalendarGrid.cells(for: date(2026, 11, 15, in: monday), calendar: monday)
        #expect(padded.prefix(6).allSatisfy { $0 == nil })
        #expect(padded.count == 36)
        #expect(padded[6] != nil)
    }

    @Test func februaryOfALeapYearHasTwentyNineDays() {
        let sunday = calendar(firstWeekday: 1)
        let days = CashCalendarGrid.cells(for: date(2028, 2, 10, in: sunday), calendar: sunday).compactMap { $0 }
        #expect(days.count == 29)
        #expect(sunday.component(.day, from: days.last!) == 29)
    }

    @Test func weekdaySymbolsStartAtTheFirstWeekday() {
        let monday = calendar(firstWeekday: 2)
        let symbols = CashCalendarGrid.weekdaySymbols(calendar: monday)
        #expect(symbols.count == 7)
        #expect(symbols.first == monday.veryShortStandaloneWeekdaySymbols[1])
        #expect(symbols.last == monday.veryShortStandaloneWeekdaySymbols[0])
    }

    @Test func startOfMonthDropsTheDay() {
        let sunday = calendar(firstWeekday: 1)
        let start = CashCalendarGrid.startOfMonth(date(2026, 11, 22, in: sunday), calendar: sunday)
        #expect(sunday.component(.day, from: start) == 1)
        #expect(sunday.component(.month, from: start) == 11)
    }
}
