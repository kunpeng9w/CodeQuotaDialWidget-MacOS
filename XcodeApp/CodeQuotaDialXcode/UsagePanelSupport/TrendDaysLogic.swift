import Foundation

/// 一个趋势日：yyyy-MM-dd 的 period 与当日数值。
struct TrendDayValue: Equatable {
    var period: String
    var value: Double
}

/// 7 日趋势的纯数据准备，抽取自 Sub2API TrendCard：截至 today 的连续
/// count 天，缺日补零，重复 period 取首见值。
enum TrendDaysLogic {
    static func trailingDays(
        values: [TrendDayValue],
        count: Int = 7,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [TrendDayValue] {
        let formatter = dayFormatter(calendar: calendar)
        let byPeriod = Dictionary(values.map { ($0.period, $0.value) }, uniquingKeysWith: { a, _ in a })
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let period = formatter.string(from: date)
            return TrendDayValue(period: period, value: byPeriod[period] ?? 0)
        }
    }

    /// 均值只算到 todayPeriod 为止的已过天数：本周未来天恒为 0，
    /// 计入会低估日均（与 UsagePanelView.WeekTrendChart 原语义一致）。
    static func elapsedAverage(_ days: [TrendDayValue], todayPeriod: String) -> Double {
        let elapsed = days.filter { $0.period <= todayPeriod }
        guard !elapsed.isEmpty else { return 0 }
        return elapsed.map(\.value).reduce(0, +) / Double(elapsed.count)
    }

    static func dayFormatter(calendar: Calendar = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
