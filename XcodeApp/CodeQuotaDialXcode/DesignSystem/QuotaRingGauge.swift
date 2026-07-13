import SwiftUI

/// 环形额度表盘：剩余百分比映射为圆环填充，颜色按 QuotaTone 分档。
/// 无数据时显示虚线轨道 + "--"。
struct QuotaRingGauge: View {
    enum Size {
        case small
        case medium
        case large

        var diameter: CGFloat {
            switch self {
            case .small: return 44
            case .medium: return 72
            case .large: return 104
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small: return 5
            case .medium: return 8
            case .large: return 10
            }
        }

        var labelFont: Font {
            switch self {
            case .small: return .system(size: 12, weight: .semibold, design: .rounded)
            case .medium: return .system(size: 17, weight: .bold, design: .rounded)
            case .large: return .system(size: 24, weight: .bold, design: .rounded)
            }
        }
    }

    var remainingPercent: Int?
    var size: Size = .medium
    var showsCenterLabel = true
    var isUnlimited = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double { QuotaGaugeLogic.fraction(remainingPercent: remainingPercent) }
    private var tone: QuotaTone { QuotaTone(QuotaGaugeLogic.tone(remainingPercent: remainingPercent)) }
    private var isUnknown: Bool { remainingPercent == nil }

    var body: some View {
        ZStack {
            if isUnknown {
                Circle()
                    .stroke(
                        Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: size.lineWidth, dash: [4, 6])
                    )
            } else {
                Circle()
                    .stroke(tone.color.opacity(0.15), lineWidth: size.lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [tone.color.opacity(0.7), tone.color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * max(fraction, 0.01))
                        ),
                        style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if showsCenterLabel {
                Text(isUnlimited ? "无限制" : remainingPercent.map { "\($0)%" } ?? "--")
                    .font(size.labelFont)
                    .foregroundStyle(isUnknown ? Color.secondary : tone.color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, size.lineWidth + 2)
            }
        }
        .frame(width: size.diameter, height: size.diameter)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: fraction)
        .accessibilityLabel(
            isUnlimited ? "无限制" : remainingPercent.map { "剩余 \($0)%" } ?? "暂无数据"
        )
    }
}

extension QuotaTone {
    /// 桥接被测 target 里的档位定义，让阈值只活在 QuotaGaugeLogic 一处。
    init(_ tone: QuotaGaugeLogic.Tone) {
        switch tone {
        case .healthy: self = .healthy
        case .low: self = .low
        case .critical: self = .critical
        case .unknown: self = .unknown
        }
    }
}
