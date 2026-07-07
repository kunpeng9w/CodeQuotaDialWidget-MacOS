import SwiftUI

/// 总览页里一个窗口的展示数据。
struct OverviewWindowItem: Identifiable {
    var title: String
    var remainingPercent: Int?

    var id: String { title }
}

/// 总览页的 provider 状态卡（紧凑版，目标是总览一屏放下）：
/// 单行头部（图标·名称·套餐·更新时间/过期警示）+ 中环表盘 + 窗口子行，
/// 整卡可点击跳转对应面板。无快照时降级为虚线环 + 「去查看」。
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

    private var isStale: Bool { OverviewSummaryLogic.isStale(generatedAt: updatedAt) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                headerRow

                HStack(spacing: DS.Space.s) {
                    QuotaRingGauge(remainingPercent: primary, size: .medium)

                    VStack(alignment: .leading, spacing: 3) {
                        if windows.isEmpty {
                            Text("暂无快照 / 未配置")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Label("去查看", systemImage: "arrow.right")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                                .labelStyle(.titleAndIcon)
                        } else {
                            ForEach(windows) { window in
                                HStack(spacing: DS.Space.xs) {
                                    Text(window.title)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: DS.Space.xxs)
                                    Text(window.remainingPercent.map { "\($0)%" } ?? "--")
                                        .font(.callout.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(
                                            QuotaTone.from(remainingPercent: window.remainingPercent).color
                                        )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(section.accent)
                    .frame(width: 18, height: 18)
            }

            Text(section.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)

            if let plan {
                TagBadge(text: plan, tint: section.accent)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            Spacer(minLength: DS.Space.xxs)

            if let warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(warning)
            }

            Text(updatedAtText)
                .font(.footnote)
                .foregroundStyle(isStale ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
                .lineLimit(1)
                .help(isStale ? "超过 30 分钟未更新，数据可能过期" : "")
        }
    }

    private var updatedAtText: String {
        guard let updatedAt else { return "未刷新" }
        let time = quotaPanelTimeFormatter.string(from: updatedAt)
        return isStale ? "⚠︎ \(time)" : time
    }
}
