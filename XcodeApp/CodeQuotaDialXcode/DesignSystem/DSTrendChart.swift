import Charts
import SwiftUI

/// Swift Charts 版 7 日趋势：柱状 + 虚线均值 + 今日高亮 + hover 显值。
/// 取代 UsagePanelView.WeekTrendChart 与 Sub2API TrendCard 的两份手绘图。
/// `import Charts` 只允许出现在 DSTrendChart / SparklineChart 两个文件里。
struct DSTrendChart: View {
    struct Day: Identifiable {
        var period: String  // yyyy-MM-dd
        var value: Double

        var id: String { period }
    }

    let days: [Day]
    var tint: Color = .blue
    var valueLabel: (Double) -> String = { dsCost($0) }

    @State private var hoveredPeriod: String?

    private var todayPeriod: String { dsDayFormatter.string(from: Date()) }

    /// 均值只算已过天数（与原 WeekTrendChart 语义一致）。
    private var average: Double {
        TrendDaysLogic.elapsedAverage(
            days.map { TrendDayValue(period: $0.period, value: $0.value) },
            todayPeriod: todayPeriod
        )
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("日期", day.period),
                    y: .value("数值", day.value)
                )
                .foregroundStyle(barColor(day))
                .cornerRadius(3)
            }

            if average > 0 {
                RuleMark(y: .value("均值", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            if let hoveredPeriod, let day = days.first(where: { $0.period == hoveredPeriod }) {
                RuleMark(x: .value("日期", day.period))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        Text(valueLabel(day.value))
                            .font(DS.Typo.meta)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: days.map(\.period)) { value in
                AxisValueLabel {
                    if let period = value.as(String.self) {
                        Text(dsWeekdayShort(period))
                            .font(DS.Typo.meta)
                            .fontWeight(period == todayPeriod ? .semibold : .regular)
                            .foregroundStyle(period == todayPeriod ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredPeriod = proxy.value(atX: location.x, as: String.self)
                        case .ended:
                            hoveredPeriod = nil
                        }
                    }
            }
        }
        .frame(height: 132)
    }

    private func barColor(_ day: Day) -> Color {
        if day.period == todayPeriod { return tint }
        if day.period == hoveredPeriod { return tint.opacity(0.75) }
        return tint.opacity(0.45)
    }
}
