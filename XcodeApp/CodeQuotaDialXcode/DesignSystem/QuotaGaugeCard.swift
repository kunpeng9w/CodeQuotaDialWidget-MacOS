import SwiftUI

/// 额度卡 v2：左侧环形表盘 + 右侧标签 / 已用 / 重置信息。
/// 内容区固定高度，保证横排的多张卡对齐。
struct QuotaGaugeCard: View {
    let title: String
    let model: QuotaStatModel?
    var detailLines: [String] = []
    /// 限额类窗口没有重置时间概念时关掉整行。
    var showsReset = true

    var body: some View {
        HStack(spacing: DS.Space.m) {
            QuotaRingGauge(remainingPercent: model?.remainingPercent, size: .medium)

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let used = model?.usedPercent {
                    Text("已用 \(used)%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(detailLines, id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if showsReset {
                    HStack(spacing: DS.Space.xxs) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(model?.resetsAt.map { dsResetFormatter.string(from: $0) } ?? "--")
                            .monospacedDigit()
                    }
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 84)
        .dsCard()
    }
}
