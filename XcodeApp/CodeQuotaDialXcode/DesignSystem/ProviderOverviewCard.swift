import SwiftUI

/// 总览页里一个窗口的展示数据。
struct OverviewWindowItem: Identifiable {
    var title: String
    var remainingPercent: Int?

    var id: String { title }
}

/// 总览页的 provider 状态卡：主表盘显示最紧张窗口，子行列出各窗口，
/// 整卡可点击跳转到对应面板。无快照时降级为虚线环 + 「去查看」。
struct ProviderOverviewCard: View {
    let section: DashboardSection
    var plan: String?
    var updatedAt: Date?
    var windows: [OverviewWindowItem]
    var warning: String?
    var onTap: () -> Void

    private var primary: Int? {
        OverviewSummaryLogic.primaryRemainingPercent(windows.map(\.remainingPercent))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                headerRow

                HStack(spacing: DS.Space.m) {
                    QuotaRingGauge(remainingPercent: primary, size: .large)

                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        if windows.isEmpty {
                            Text("暂无快照 / 未配置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label("去查看", systemImage: "arrow.right")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                                .labelStyle(.titleAndIcon)
                        } else {
                            ForEach(windows) { window in
                                HStack(spacing: DS.Space.xs) {
                                    Text(window.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer(minLength: DS.Space.xs)
                                    Text(window.remainingPercent.map { "\($0)%" } ?? "--")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(
                                            QuotaTone.from(remainingPercent: window.remainingPercent).color
                                        )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 150, alignment: .leading)

                    Spacer(minLength: 0)
                }

                Text(updatedAt.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0))" } ?? "未刷新")
                    .font(DS.Typo.meta)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .dsHoverOutline(tint: section.accent)
    }

    private var headerRow: some View {
        HStack(spacing: DS.Space.xs) {
            if let asset = section.iconAsset {
                Image(asset)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(section.accent)
                    .frame(width: 20, height: 20)
            }

            Text(section.title)
                .font(.callout.weight(.semibold))

            if let plan {
                TagBadge(text: plan, tint: section.accent)
            }

            Spacer(minLength: 0)

            if let warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(warning)
            }

            if OverviewSummaryLogic.isStale(generatedAt: updatedAt) {
                TagBadge(text: "可能过期", tint: .orange, muted: true)
            }
        }
    }
}
