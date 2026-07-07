import Foundation

/// 环形额度表盘的纯计算：进度分数与健康档位。阈值与 Theme.swift 的
/// QuotaTone（≥50 充足 / ≥20 偏低 / <20 紧张）保持一致，由测试钉死。
enum QuotaGaugeLogic {
    enum Tone: Equatable {
        case healthy
        case low
        case critical
        case unknown
    }

    static func fraction(remainingPercent: Int?) -> Double {
        guard let percent = remainingPercent else { return 0 }
        return min(1, max(0, Double(percent) / 100))
    }

    static func tone(remainingPercent: Int?) -> Tone {
        guard let percent = remainingPercent else { return .unknown }
        if percent >= 50 { return .healthy }
        if percent >= 20 { return .low }
        return .critical
    }
}
