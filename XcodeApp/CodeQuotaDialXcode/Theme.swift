import SwiftUI

// MARK: - 额度分级配色

/// 按剩余百分比把额度窗口分成四档，决定卡片里大号数字与进度条的颜色。
enum QuotaTone {
    case healthy   // 充足
    case low       // 偏低
    case critical  // 紧张
    case unknown   // 无数据

    static func from(remainingPercent: Int?) -> QuotaTone {
        guard let percent = remainingPercent else { return .unknown }
        if percent >= 50 { return .healthy }
        if percent >= 20 { return .low }
        return .critical
    }

    var color: Color {
        switch self {
        case .healthy:  return .green
        case .low:      return .orange
        case .critical: return .red
        case .unknown:  return .secondary
        }
    }
}

// MARK: - 设计 token

enum Theme {
    static let cornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 12
    static let spacing: CGFloat = 18
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let contentPadding: CGFloat = 24

    /// 卡片表面材质，浅/深色模式自动适配。
    static let cardBackground: Material = .regularMaterial
    /// 整窗背景材质。
    static let panelBackground: Material = .thinMaterial
}

// MARK: - 统一卡片表面

extension View {
    /// 兼容旧调用：转发到设计系统的 `dsCard`，防止两套卡片表面并存漂移。
    func cardSurface(padded: Bool = true) -> some View {
        dsCard(.raised, padded: padded)
    }
}

// MARK: - 通用小组件

/// 标题旁的胶囊徽标（套餐 / 等级等）。
struct TagBadge: View {
    let text: String
    var tint: Color = .blue
    var muted: Bool = false

    var body: some View {
        let color = muted ? Color.secondary : tint
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// 工具栏里的刷新按钮（带进行中态）。
struct RefreshButton: View {
    let isRefreshing: Bool
    var helpText: String = "立即刷新"
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            if isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Label("刷新", systemImage: "arrow.clockwise")
            }
        }
        .disabled(isRefreshing)
        .help(helpText)
    }
}

/// 内联提示横幅（错误 / 警告）。
struct InlineBanner: View {
    let text: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

/// 面板底部的灰色说明脚注（带图标）。
struct FootnoteRow: View {
    let text: String
    var systemImage: String = "info.circle"

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

// MARK: - 卡片数据模型

/// 统一 Codex / GLM 两种窗口类型的展示数据，避免卡片组件依赖具体模型。
struct QuotaStatModel {
    var remainingPercent: Int?
    var usedPercent: Int?
    var absoluteText: String?   // 例如 GLM 的 "remaining/total"
    var resetsAt: Date?
    var isUnlimited = false
}

// MARK: - 后台运行状态

enum AgentStatus: Sendable {
    case running
    case stopped
    case notInstalled
    case checking

    var dotColor: Color {
        switch self {
        case .running:      return .green
        case .stopped:      return .secondary
        case .notInstalled: return .orange
        case .checking:     return .secondary
        }
    }

    var label: String {
        switch self {
        case .running:      return "运行中"
        case .stopped:      return "已停止"
        case .notInstalled: return "未安装"
        case .checking:     return "检查中"
        }
    }

    var isPulsing: Bool { self == .running }
}

struct StatusDot: View {
    let status: AgentStatus
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 8, height: 8)
                .scaleEffect(status.isPulsing && pulsing ? 1.3 : 1.0)
                .opacity(status.isPulsing ? (pulsing ? 0.55 : 1.0) : 1.0)
                .animation(
                    status.isPulsing
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
            Text(status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { pulsing = status.isPulsing }
        .onChange(of: status) { _, newValue in pulsing = newValue.isPulsing }
    }
}
