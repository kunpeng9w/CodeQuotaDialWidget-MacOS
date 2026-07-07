import SwiftUI

/// KPI 卡：小标签 + 主数值 + 次级说明。
/// 统一 PeriodTile（消耗统计）、summaryStat（模型价格）、
/// TotalTile / NaturalMonthMetric（Sub2API）。
struct KPICard: View {
    let label: String
    let value: String
    var secondary: String?
    var tint: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(label)
                .font(DS.Typo.cardLabel)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(DS.Typo.metricM)
                .foregroundStyle(tint ?? Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let secondary {
                Text(secondary)
                    .font(DS.Typo.meta)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .dsCard()
    }
}

/// 行内 KPI：卡内的 token 输入 / 输出 / 缓存等小数值列，
/// 吸收 UsagePanelView 与 Sub2APIQuotaPanelView 的两份 TokenValue。
struct KPIInline: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DS.Typo.meta)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
