import Sub2APIQuotaCore
import SwiftUI
import WidgetKit

public struct Sub2APIQuotaEntry: TimelineEntry {
    public let date: Date
    public let snapshot: Sub2APISnapshot?

    public init(date: Date, snapshot: Sub2APISnapshot?) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct Sub2APIQuotaProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> Sub2APIQuotaEntry {
        Sub2APIQuotaEntry(date: Date(), snapshot: nil)
    }

    public func getSnapshot(in context: Context, completion: @escaping (Sub2APIQuotaEntry) -> Void) {
        completion(Sub2APIQuotaEntry(date: Date(), snapshot: try? Sub2APIQuotaSnapshotStore().load()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<Sub2APIQuotaEntry>) -> Void) {
        let entry = Sub2APIQuotaEntry(date: Date(), snapshot: try? Sub2APIQuotaSnapshotStore().load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

public struct Sub2APIQuotaWidgetEntryView: View {
    public var entry: Sub2APIQuotaEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: Sub2APIQuotaEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let snapshot = entry.snapshot, !snapshot.accounts.isEmpty {
            Sub2APIWidgetDashboard(snapshot: snapshot, family: family)
        } else {
            EmptySub2APIView()
        }
    }
}

public struct Sub2APIQuotaDialWidget: Widget {
    public let kind = "Sub2APIQuotaDialWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Sub2APIQuotaProvider()) { entry in
            Sub2APIQuotaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sub2API 统计")
        .description("显示 Sub2API 中转站的今日/本周限额与自然月总额。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct Sub2APIWidgetDashboard: View {
    var snapshot: Sub2APISnapshot
    var family: WidgetFamily

    var body: some View {
        switch family {
        case .systemMedium:
            MediumSub2APIDashboard(snapshot: snapshot)
        default:
            LargeSub2APIDashboard(snapshot: snapshot)
        }
    }
}

private struct MediumSub2APIDashboard: View {
    var snapshot: Sub2APISnapshot

    var body: some View {
        let overview = snapshot.overview
        VStack(alignment: .leading, spacing: 8) {
            Sub2APIWidgetHeader(snapshot: snapshot, overview: overview)

            HStack(spacing: 8) {
                CompactLimitTile(title: "日限额", window: overview.daily, tint: .cyan)
                CompactLimitTile(title: "周限额", window: overview.weekly, tint: .indigo)
                NaturalMonthTile(summary: overview.naturalMonthSummary(), tint: .purple)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct LargeSub2APIDashboard: View {
    var snapshot: Sub2APISnapshot

    var body: some View {
        let overview = snapshot.overview
        VStack(alignment: .leading, spacing: 9) {
            Sub2APIWidgetHeader(snapshot: snapshot, overview: overview)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    TodayCostColumn(overview: overview, costFontSize: 32)
                    DailyTokenValues(summary: overview.today)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    LimitMiniRow(title: "日", window: overview.daily)
                    LimitMiniRow(title: "周", window: overview.weekly)
                    NaturalMonthMiniRow(title: "自然月", summary: overview.naturalMonthSummary())
                }
                .frame(width: 146)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("近 7 天趋势")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Sub2APIWeekTrend(days: overview.days, height: 44, showsLabels: true, expands: true)
            }

            HStack(alignment: .top, spacing: 14) {
                AccountsColumn(accounts: snapshot.accounts)
                TopModelsColumn(models: overview.models)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct Sub2APIWidgetHeader: View {
    var snapshot: Sub2APISnapshot
    var overview: Sub2APIAccountReport

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Sub2API")
                .font(.subheadline.weight(.semibold))
            if let plan = overview.planName {
                Text(plan)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if snapshot.accounts.count > 1 {
                Text("\(snapshot.accounts.count) 个账号")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)
            }
            Spacer()
            Text("更新 \(widgetTimeFormatter.string(from: snapshot.generatedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TodayCostColumn: View {
    var overview: Sub2APIAccountReport
    var costFontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("今日消耗")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(costText(overview.today.actualCost))
                .font(.system(size: costFontSize, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("标准 \(costText(overview.today.cost)) · \(compactNumber(overview.today.totalTokens)) tokens")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct LimitMiniRow: View {
    var title: String
    var window: Sub2APILimitWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(window.map { "\(costText($0.usageUSD)) / \(limitText($0.limitUSD))" } ?? "--")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    if let window {
                        Capsule()
                            .fill(limitTone(window))
                            .frame(width: geo.size.width * min(1, Double(window.usedPercent) / 100))
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NaturalMonthMiniRow: View {
    var title: String
    var summary: Sub2APITokenSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(costText(summary.actualCost))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text("标准 \(costText(summary.cost)) · \(compactNumber(summary.totalTokens)) tokens")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CompactLimitTile: View {
    var title: String
    var window: Sub2APILimitWindow?
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(window.map { "\($0.remainingPercent)%" } ?? "--")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(window.map(limitTone) ?? .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    if let window {
                        Capsule()
                            .fill(tint.opacity(0.8))
                            .frame(width: geo.size.width * min(1, Double(window.usedPercent) / 100))
                    }
                }
            }
            .frame(height: 5)

            Text(window.map { "已用 \(costText($0.usageUSD)) / \(limitText($0.limitUSD))" } ?? "暂无限额")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct NaturalMonthTile: View {
    var summary: Sub2APITokenSummary
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("自然月")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(costText(summary.actualCost))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("标准 \(costText(summary.cost))")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(compactNumber(summary.totalTokens)) tokens")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DailyTokenValues: View {
    var summary: Sub2APITokenSummary

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            TokenMetric(title: "输入", value: summary.inputTokens)
            TokenMetric(title: "输出", value: summary.outputTokens)
            TokenMetric(title: "缓存写", value: summary.cacheCreationTokens)
            TokenMetric(title: "缓存读", value: summary.cacheReadTokens)
        }
    }
}

private struct TokenMetric: View {
    var title: String
    var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(compactTokenMetric(value))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Sub2APIWeekTrend: View {
    var days: [Sub2APIDayUsage]
    var height: CGFloat = 44
    var showsLabels: Bool = false
    /// Expanding bars soak up the widget's leftover vertical space so short
    /// content doesn't get centered with big top/bottom margins.
    var expands: Bool = false

    /// The trailing 7 local days, zero-filled where the report has no row.
    private var weekDays: [Sub2APIDayUsage] {
        let byPeriod = Dictionary(days.map { ($0.period, $0.summary) }, uniquingKeysWith: { a, _ in a })
        return (0..<7).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let period = widgetDayFormatter.string(from: date)
            return Sub2APIDayUsage(period: period, summary: byPeriod[period] ?? Sub2APITokenSummary())
        }
    }

    var body: some View {
        let weekDays = weekDays
        let maxCost = max(weekDays.map(\.summary.actualCost).max() ?? 0, 0.01)
        let todayPeriod = widgetDayFormatter.string(from: Date())

        HStack(alignment: .bottom, spacing: 6) {
            ForEach(weekDays) { day in
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(0.35 + 0.6 * (day.summary.actualCost / maxCost)))
                                .frame(height: max(3, geo.size.height * day.summary.actualCost / maxCost))
                                .overlay {
                                    if day.period == todayPeriod {
                                        RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(Color.primary.opacity(0.5), lineWidth: 1)
                                    }
                                }
                        }
                    }
                    .frame(minHeight: height, maxHeight: expands ? .infinity : height)

                    if showsLabels {
                        Text(weekdayShort(day.period))
                            .font(.system(size: 8, weight: day.period == todayPeriod ? .semibold : .regular))
                            .foregroundStyle(.secondary)
                        Text(costText(day.summary.actualCost))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct AccountsColumn: View {
    var accounts: [Sub2APIAccountReport]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("账号(今日)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(accounts.prefix(2)) { account in
                HStack {
                    Text(account.name)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    if account.error != nil {
                        Text("失败")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(costText(account.today.actualCost))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TopModelsColumn: View {
    var models: [Sub2APIModelStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("累计模型")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(models.prefix(2)) { model in
                HStack {
                    Text(model.name)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(costText(model.summary.actualCost))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptySub2APIView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sub2API 统计")
                .font(.headline)
            Text("暂无数据")
                .font(.title3.weight(.semibold))
            Text("在 app 的 Sub2API 页面添加账号并刷新")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private func limitTone(_ window: Sub2APILimitWindow) -> Color {
    let remaining = window.remainingPercent
    if remaining >= 50 { return .green }
    if remaining >= 20 { return .orange }
    return .red
}

private func costText(_ value: Double) -> String {
    String(format: "$%.2f", value)
}

/// Limits are round numbers ($160 / $800); drop the cents to keep the mini
/// rows readable.
private func limitText(_ value: Double) -> String {
    value == value.rounded() ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
}

private func compactNumber(_ value: Int) -> String {
    let number = Double(value)
    if number >= 1_000_000_000 {
        return String(format: "%.1fB", number / 1_000_000_000)
    }
    if number >= 1_000_000 {
        return String(format: "%.1fM", number / 1_000_000)
    }
    if number >= 1_000 {
        return String(format: "%.1fK", number / 1_000)
    }
    return "\(value)"
}

/// Tighter token formatter for the four-up daily breakdown row; keeps every
/// value ≤4 chars so the columns render at one uniform size.
private func compactTokenMetric(_ value: Int) -> String {
    let number = Double(value)
    func scaled(_ divisor: Double, _ suffix: String) -> String {
        let v = number / divisor
        return v < 10 ? String(format: "%.1f%@", v, suffix) : String(format: "%.0f%@", v, suffix)
    }
    if number >= 1_000_000_000 { return scaled(1_000_000_000, "B") }
    if number >= 1_000_000 { return scaled(1_000_000, "M") }
    if number >= 1_000 { return scaled(1_000, "K") }
    return "\(value)"
}

private func weekdayShort(_ period: String) -> String {
    guard let date = widgetDayFormatter.date(from: period) else { return "" }
    let index = Calendar.current.component(.weekday, from: date)
    let labels = ["日", "一", "二", "三", "四", "五", "六"]
    return labels[max(0, min(6, index - 1))]
}

private let widgetTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
}()

private let widgetDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
