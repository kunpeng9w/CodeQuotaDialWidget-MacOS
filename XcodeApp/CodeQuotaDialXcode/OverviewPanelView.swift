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
    /// 设置页「主页面显示」里熄灭的服务，卡片网格据此过滤。
    @State private var disabledProviders: Set<String> = []

    var body: some View {
        // 总览不走 PanelScaffold：省掉大头部与区块标题，目标是默认窗口下
        // 五张 provider 卡 + 今日消耗条一屏放下、无需滚动。
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                providerGrid
                usageTodayStrip
            }
            .padding(DS.Space.m)
            .frame(maxWidth: 1024, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
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
        .onReceive(NotificationCenter.default.publisher(for: .runtimeConfigDidChange)) { _ in
            disabledProviders = Set(RuntimeConfigStore.load().disabledProviders)
        }
    }

    private func isEnabled(_ section: DashboardSection) -> Bool {
        !disabledProviders.contains(section.rawValue)
    }

    private var providerGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DS.Space.s, alignment: .top),
                GridItem(.flexible(), spacing: DS.Space.s, alignment: .top),
                GridItem(.flexible(), spacing: DS.Space.s, alignment: .top),
            ],
            alignment: .leading,
            spacing: DS.Space.s
        ) {
            if isEnabled(.codex) {
                ProviderOverviewCard(
                    section: .codex,
                    plan: codex?.planType?.uppercased(),
                    updatedAt: codex?.generatedAt,
                    windows: codexWindows,
                    warning: codex?.error,
                    onTap: { onNavigate(.codex) }
                )
            }
            if isEnabled(.claude) {
                ProviderOverviewCard(
                    section: .claude,
                    plan: claude?.planType?.uppercased(),
                    updatedAt: claude?.generatedAt,
                    windows: claudeWindows,
                    warning: claude?.error,
                    onTap: { onNavigate(.claude) }
                )
            }
            if isEnabled(.glm) {
                ProviderOverviewCard(
                    section: .glm,
                    plan: glm?.level?.uppercased(),
                    updatedAt: glm?.generatedAt,
                    windows: glmWindows,
                    warning: glm?.error,
                    onTap: { onNavigate(.glm) }
                )
            }
            if isEnabled(.antigravity) {
                ProviderOverviewCard(
                    section: .antigravity,
                    plan: antigravity?.planType?.uppercased(),
                    updatedAt: antigravity?.generatedAt,
                    windows: antigravityWindows,
                    warning: antigravity?.error,
                    onTap: { onNavigate(.antigravity) }
                )
            }
            if isEnabled(.sub2api) {
                ProviderOverviewCard(
                    section: .sub2api,
                    plan: sub2apiPrimaryReport?.planName,
                    updatedAt: sub2api?.generatedAt,
                    windows: sub2apiWindows,
                    warning: sub2api?.error ?? sub2apiPrimaryReport?.error,
                    onTap: { onNavigate(.sub2api) }
                )
            }
        }
    }

    // MARK: - 今日消耗（横条）

    private var usageTodayStrip: some View {
        Button {
            onNavigate(.usage)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                DSSectionHeader(
                    "今日消耗",
                    subtitle: usage.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0.generatedAt))" } ?? "未刷新"
                )

                HStack(alignment: .center, spacing: DS.Space.l) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dsCost(usage?.daily.totalCost))
                            .font(DS.Typo.metricL)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(dsCompactNumber(usage?.daily.totalTokens)) tokens")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    KPIInline(label: "本周", value: dsCost(usage?.weekly.totalCost))
                        .frame(maxWidth: 110)
                    KPIInline(label: "本月", value: dsCost(usage?.monthly.totalCost))
                        .frame(maxWidth: 110)
                    KPIInline(label: "总计", value: dsCost(usage?.total.totalCost))
                        .frame(maxWidth: 110)

                    Spacer(minLength: 0)

                    SparklineChart(values: weekCostValues, tint: .blue)
                        .frame(width: 160)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .dsHoverOutline(tint: DashboardSection.usage.accent)
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
        disabledProviders = Set(RuntimeConfigStore.load().disabledProviders)
        codex = try? CodexQuotaSnapshotStore().load()
        claude = try? ClaudeQuotaSnapshotStore().load()
        glm = try? GLMQuotaSnapshotStore().load()
        antigravity = try? AntigravityQuotaSnapshotStore().load()
        sub2api = try? Sub2APIQuotaSnapshotStore().load()
        usage = try? UsageSnapshotStore().load()
    }

    /// 并发刷新所有「点亮」的服务；被隐藏的服务跳过（保留原快照）。
    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let newCodex = refreshCodexIfEnabled()
        async let newClaude = refreshClaudeIfEnabled()
        async let newGLM = refreshGLMIfEnabled()
        async let newAntigravity = refreshAntigravityIfEnabled()
        async let newSub2api = refreshSub2apiIfEnabled()
        let usageTask = Task.detached { UsageCollector().collect() }

        codex = await newCodex
        claude = await newClaude
        glm = await newGLM
        antigravity = await newAntigravity
        sub2api = await newSub2api

        let newUsage = await usageTask.value
        if (try? UsageSnapshotStore().save(newUsage)) != nil {
            usage = newUsage
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refreshCodexIfEnabled() async -> CodexQuotaSnapshot? {
        guard isEnabled(.codex) else { return codex }
        return await refreshQuotaPanelSnapshot(
            store: CodexQuotaSnapshotStore(),
            currentSnapshot: codex,
            fallbackReason: "未返回额度窗口"
        ) { CodexQuotaCollector().collect() }.snapshot
    }

    private func refreshClaudeIfEnabled() async -> ClaudeQuotaSnapshot? {
        guard isEnabled(.claude) else { return claude }
        return await refreshQuotaPanelSnapshot(
            store: ClaudeQuotaSnapshotStore(),
            currentSnapshot: claude,
            fallbackReason: "未返回额度窗口"
        ) { ClaudeQuotaCollector().collect() }.snapshot
    }

    private func refreshGLMIfEnabled() async -> GLMQuotaSnapshot? {
        guard isEnabled(.glm) else { return glm }
        return await refreshQuotaPanelSnapshot(
            store: GLMQuotaSnapshotStore(),
            currentSnapshot: glm,
            fallbackReason: "未返回额度窗口"
        ) { GLMQuotaCollector().collect() }.snapshot
    }

    private func refreshAntigravityIfEnabled() async -> AntigravityQuotaSnapshot? {
        guard isEnabled(.antigravity) else { return antigravity }
        return await refreshQuotaPanelSnapshot(
            store: AntigravityQuotaSnapshotStore(),
            currentSnapshot: antigravity,
            fallbackReason: "未返回目标模型额度"
        ) { AntigravityQuotaCollector().collect() }.snapshot
    }

    private func refreshSub2apiIfEnabled() async -> Sub2APISnapshot? {
        guard isEnabled(.sub2api) else { return sub2api }
        return await refreshQuotaPanelSnapshot(
            store: Sub2APIQuotaSnapshotStore(),
            currentSnapshot: sub2api,
            fallbackReason: "未返回账号数据"
        ) { Sub2APIQuotaCollector().collect() }.snapshot
    }
}
