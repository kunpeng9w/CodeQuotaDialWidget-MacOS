import Foundation
import Testing

@testable import UsagePanelSupport

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func utcDate(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

@Test func trailingDaysZeroFillsMissingDaysAndDropsOutOfWindowValues() {
    let days = TrendDaysLogic.trailingDays(
        values: [
            TrendDayValue(period: "2026-07-06", value: 3.5),
            TrendDayValue(period: "2026-06-25", value: 9),
        ],
        count: 7,
        today: utcDate("2026-07-07T09:00:00Z"),
        calendar: utcCalendar()
    )

    #expect(days.map(\.period) == [
        "2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04",
        "2026-07-05", "2026-07-06", "2026-07-07",
    ])
    #expect(days.map(\.value) == [0, 0, 0, 0, 0, 3.5, 0])
}

@Test func trailingDaysKeepsFirstValueForDuplicatePeriods() {
    let days = TrendDaysLogic.trailingDays(
        values: [
            TrendDayValue(period: "2026-07-06", value: 3.5),
            TrendDayValue(period: "2026-07-06", value: 99),
        ],
        count: 7,
        today: utcDate("2026-07-07T09:00:00Z"),
        calendar: utcCalendar()
    )

    #expect(days.first { $0.period == "2026-07-06" }?.value == 3.5)
}

@Test func trailingDaysCrossesMonthBoundary() {
    let days = TrendDaysLogic.trailingDays(
        values: [TrendDayValue(period: "2026-06-28", value: 1)],
        count: 7,
        today: utcDate("2026-07-03T00:30:00Z"),
        calendar: utcCalendar()
    )

    #expect(days.map(\.period) == [
        "2026-06-27", "2026-06-28", "2026-06-29", "2026-06-30",
        "2026-07-01", "2026-07-02", "2026-07-03",
    ])
    #expect(days[1].value == 1)
}

@Test func elapsedAverageIgnoresFutureDays() {
    let days = [
        TrendDayValue(period: "2026-07-01", value: 1),
        TrendDayValue(period: "2026-07-02", value: 2),
        TrendDayValue(period: "2026-07-03", value: 3),
        TrendDayValue(period: "2026-07-04", value: 4),
        TrendDayValue(period: "2026-07-05", value: 0),
        TrendDayValue(period: "2026-07-06", value: 0),
        TrendDayValue(period: "2026-07-07", value: 0),
    ]

    #expect(TrendDaysLogic.elapsedAverage(days, todayPeriod: "2026-07-04") == 2.5)
    #expect(TrendDaysLogic.elapsedAverage([], todayPeriod: "2026-07-04") == 0)
}
