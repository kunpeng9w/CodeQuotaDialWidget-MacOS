import AntigravityQuotaCore
import ClaudeQuotaCore
import CodexQuotaCore
import GLMQuotaCore
import Sub2APIQuotaCore
import SwiftUI
import UsageQuotaCore
import WidgetKit

/// 总览首页：所有 provider 的额度状态卡 + 今日消耗摘要。
/// onAppear 只读快照（不跑采集器、无定时器）；「全部刷新」显式并发刷新全部数据源。
struct OverviewPanelView: View {
    var onNavigate: (DashboardSection) -> Void

    @State private var codex: CodexQuotaSnapshot?
    @State private var claude: ClaudeQuotaSnapshot?
    @State private var glm: GLMQuotaSnapshot?
    @State private var antigravity: AntigravityQuotaSnapshot?
    @State private var sub2api: Sub2APISnapshot?
    @State private var usage: UsageSnapshot?
    @State private var isRefreshing = false

    var body: some View {
        PanelScaffold(section: .overview) {
            DSSectionHeader("额度监控")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 300), spacing: DS.Space.s, alignment: .top)],
                alignment: .leading,
                spacing: DS.Space.s
            ) {
                ProviderOverviewCard(
                    section: .codex,
                    plan: codex?.planType?.uppercased(),
                    updatedAt: codex?.generatedAt,
                    windows: codexWindows,
                    warning: codex?.error,
                    onTap: { onNavigate(.codex) }
                )
                ProviderOverviewCard(
                    section: .claude,
                    plan: claude?.planType?.uppercased(),
                    updatedAt: claude?.generatedAt,
                    windows: claudeWindows,
                    warning: claude?.error,
                    onTap: { onNavigate(.claude) }
                )
                ProviderOverviewCard(
                    section: .glm,
                    plan: glm?.level?.uppercased(),
                    updatedAt: glm?.generatedAt,
                    windows: glmWindows,
                    warning: glm?.error,
                    onTap: { onNavigate(.glm) }
                )
                ProviderOverviewCard(
                    section: .antigravity,
                    plan: antigravity?.planType?.uppercased(),
                    updatedAt: antigravity?.generatedAt,
                    windows: antigravityWindows,
                    warning: antigravity?.error,
                    onTap: { onNavigate(.antigravity) }
                )
                ProviderOverviewCard(
                    section: .sub2api,
                    plan: sub2apiPrimaryReport?.planName,
                    updatedAt: sub2api?.generatedAt,
                    windows: sub2apiWindows,
                    warning: sub2api?.error ?? sub2apiPrimaryReport?.error,
                    onTap: { onNavigate(.sub2api) }
                )
            }

            DSSectionHeader("用量统计")

            HStack(alignment: .top, spacing: DS.Space.s) {
                usageTodayCard

                if let report = sub2apiPrimaryReport {
                    sub2apiTodayCard(report)
                        .frame(maxWidth: 300)
                }
            }
        }
        .navigationTitle("总览")
        .navigationSubtitle("所有数据源一览")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshButton(
                    isRefreshing: isRefreshing,
                    helpText: "刷新全部数据源"
                ) { await refreshAll() }
            }
        }
        .onAppear(perform: loadAll)
    }

    // MARK: - 今日消耗

    private var usageTodayCard: some View {
        Button {
            onNavigate(.usage)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                DSSectionHeader(
                    "今日消耗",
                    subtitle: usage.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0.generatedAt))" } ?? "未刷新"
                )

                HStack(alignment: .center, spacing: DS.Space.l) {
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text(dsCost(usage?.daily.totalCost))
                            .font(DS.Typo.metricXL)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(dsCompactNumber(usage?.daily.totalTokens)) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    SparklineChart(values: weekCostValues, tint: .blue)
                        .frame(width: 180)
                }

                HStack(spacing: DS.Space.s) {
                    KPIInline(label: "本周", value: dsCost(usage?.weekly.totalCost))
                    KPIInline(label: "本月", value: dsCost(usage?.monthly.totalCost))
                    KPIInline(label: "总计", value: dsCost(usage?.total.totalCost))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .dsHoverOutline(tint: DashboardSection.usage.accent)
    }

    private func sub2apiTodayCard(_ report: Sub2APIAccountReport) -> some View {
        Button {
            onNavigate(.sub2api)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                DSSectionHeader("Sub2API 今日")

                HStack(spacing: DS.Space.s) {
                    QuotaRingGauge(remainingPercent: report.daily?.remainingPercent, size: .medium)

                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text(dsCost(report.today.actualCost))
                            .font(DS.Typo.metricM)
                            .monospacedDigit()
                        if let daily = report.daily {
                            Text("日限额已用 \(dsCost(daily.usageUSD)) / \(dsLimitCost(daily.limitUSD))")
                                .font(DS.Typo.meta)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .dsHoverOutline(tint: DashboardSection.sub2api.accent)
    }

    private var weekCostValues: [Double] {
        let days = (usage?.weekDays ?? []).map { TrendDayValue(period: $0.period, value: $0.totalCost) }
        guard !days.isEmpty else { return [] }
        return TrendDaysLogic.trailingDays(values: days).map(\.value)
    }

    // MARK: - 各 provider 的窗口摘要

    private var codexWindows: [OverviewWindowItem] {
        guard let codex else { return [] }
        if let monthly = codex.monthly, codex.fiveHour == nil {
            return [OverviewWindowItem(title: "30 天", remainingPercent: monthly.remainingPercent)]
        }
        return [
            OverviewWindowItem(title: "5h", remainingPercent: codex.fiveHour?.remainingPercent),
            OverviewWindowItem(title: "本周", remainingPercent: codex.weekly?.remainingPercent),
        ]
    }

    private var claudeWindows: [OverviewWindowItem] {
        guard let claude else { return [] }
        return [
            OverviewWindowItem(title: "5h", remainingPercent: claude.fiveHour?.remainingPercent),
            OverviewWindowItem(title: "本周", remainingPercent: claude.weekly?.remainingPercent),
        ]
    }

    private var glmWindows: [OverviewWindowItem] {
        guard let glm else { return [] }
        return [
            OverviewWindowItem(title: "工具类", remainingPercent: glm.timeLimit?.remainingPercent),
            OverviewWindowItem(title: "5h", remainingPercent: glm.tokensLimit5?.remainingPercent),
            OverviewWindowItem(title: "本周", remainingPercent: glm.tokensLimitWeek?.remainingPercent),
        ]
    }

    private var antigravityWindows: [OverviewWindowItem] {
        guard let antigravity else { return [] }
        return AntigravityQuotaBucket.allCases.compactMap { bucket in
            antigravity.model(for: bucket).map {
                OverviewWindowItem(title: bucket.displayName, remainingPercent: $0.remainingPercent)
            }
        }
    }

    private var sub2apiWindows: [OverviewWindowItem] {
        guard let report = sub2apiPrimaryReport else { return [] }
        return [
            OverviewWindowItem(title: "日限额", remainingPercent: report.daily?.remainingPercent),
            OverviewWindowItem(title: "周限额", remainingPercent: report.weekly?.remainingPercent),
        ]
    }

    /// 与 Sub2API 面板同规则：单账号取该账号，多账号取聚合总览。
    private var sub2apiPrimaryReport: Sub2APIAccountReport? {
        guard let sub2api, !sub2api.accounts.isEmpty else { return nil }
        if sub2api.accounts.count == 1 { return sub2api.accounts[0] }
        return sub2api.overview
    }

    // MARK: - 加载与刷新

    private func loadAll() {
        codex = try? CodexQuotaSnapshotStore().load()
        claude = try? ClaudeQuotaSnapshotStore().load()
        glm = try? GLMQuotaSnapshotStore().load()
        antigravity = try? AntigravityQuotaSnapshotStore().load()
        sub2api = try? Sub2APIQuotaSnapshotStore().load()
        usage = try? UsageSnapshotStore().load()
    }

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let codexState = refreshQuotaPanelSnapshot(
            store: CodexQuotaSnapshotStore(),
            currentSnapshot: codex,
            fallbackReason: "未返回额度窗口"
        ) { CodexQuotaCollector().collect() }
        async let claudeState = refreshQuotaPanelSnapshot(
            store: ClaudeQuotaSnapshotStore(),
            currentSnapshot: claude,
            fallbackReason: "未返回额度窗口"
        ) { ClaudeQuotaCollector().collect() }
        async let glmState = refreshQuotaPanelSnapshot(
            store: GLMQuotaSnapshotStore(),
            currentSnapshot: glm,
            fallbackReason: "未返回额度窗口"
        ) { GLMQuotaCollector().collect() }
        async let antigravityState = refreshQuotaPanelSnapshot(
            store: AntigravityQuotaSnapshotStore(),
            currentSnapshot: antigravity,
            fallbackReason: "未返回目标模型额度"
        ) { AntigravityQuotaCollector().collect() }
        async let sub2apiState = refreshQuotaPanelSnapshot(
            store: Sub2APIQuotaSnapshotStore(),
            currentSnapshot: sub2api,
            fallbackReason: "未返回账号数据"
        ) { Sub2APIQuotaCollector().collect() }
        let usageTask = Task.detached { UsageCollector().collect() }

        codex = await codexState.snapshot
        claude = await claudeState.snapshot
        glm = await glmState.snapshot
        antigravity = await antigravityState.snapshot
        sub2api = await sub2apiState.snapshot

        let newUsage = await usageTask.value
        if (try? UsageSnapshotStore().save(newUsage)) != nil {
            usage = newUsage
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
