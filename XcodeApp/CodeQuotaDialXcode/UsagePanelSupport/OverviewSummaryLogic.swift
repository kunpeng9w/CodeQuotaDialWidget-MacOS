import Foundation

/// 总览页的纯聚合逻辑。
enum OverviewSummaryLogic {
    /// 主表盘取最紧张（剩余百分比最小）的窗口；全部无数据 → nil。
    static func primaryRemainingPercent(_ percents: [Int?]) -> Int? {
        percents.compactMap { $0 }.min()
    }

    /// 快照超过 maxAge（默认 30 分钟）未更新视为可能过期；无快照不算过期。
    static func isStale(
        generatedAt: Date?,
        now: Date = .now,
        maxAge: TimeInterval = 30 * 60
    ) -> Bool {
        guard let generatedAt else { return false }
        return now.timeIntervalSince(generatedAt) > maxAge
    }
}
