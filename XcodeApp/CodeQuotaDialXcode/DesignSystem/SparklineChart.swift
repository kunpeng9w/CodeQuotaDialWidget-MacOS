import Charts
import SwiftUI

/// 迷你 7 日趋势：无坐标轴，末柱（今天）高亮。总览「今日消耗」卡使用。
struct SparklineChart: View {
    let values: [Double]
    var tint: Color = .accentColor

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            BarMark(
                x: .value("日", index),
                y: .value("值", value)
            )
            .foregroundStyle(index == values.count - 1 ? tint : tint.opacity(0.35))
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }
}
