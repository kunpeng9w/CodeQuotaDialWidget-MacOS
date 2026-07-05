import Combine
import Sub2APIQuotaCore
import SwiftUI
import WidgetKit

/// Sub2API relay stats: multi-account (each with its own base URL + key +
/// display name), an aggregate "总览" scope, the relay's daily/weekly spending
/// limits plus a local natural-month total, and usage cards modeled on the
/// 消耗统计 panel. The primary money figure everywhere is `actual_cost`
/// (实际扣费,与限额同口径); the upstream list price is shown as secondary text.
struct Sub2APIQuotaPanelView: View {
    @State private var snapshot: Sub2APISnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @State private var selectedScopeID = "overview"

    @State private var accounts: [Sub2APIAccountEntry] = []
    @State private var isEditingAccount = false
    @State private var editingAccountID: String?
    @State private var formName = ""
    @State private var formBaseURL = ""
    @State private var formApiKey = ""
    @State private var accountStatus: String?

    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.sub2api.label,
        plistPath: LaunchAgentLabels.sub2api.plist
    )

    private let refreshTimer = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                if let plan = selectedReport?.planName {
                    HStack(spacing: 8) {
                        TagBadge(text: plan, tint: .indigo)
                        if let mode = selectedReport?.mode {
                            TagBadge(text: mode.uppercased(), tint: .blue, muted: true)
                        }
                    }
                }

                LaunchAgentToggleRow(controller: agent)

                accountsCard

                if scopeOptions.count > 1 {
                    Picker("范围", selection: $selectedScopeID) {
                        ForEach(scopeOptions, id: \.id) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260, alignment: .leading)
                }

                if let report = selectedReport {
                    HStack(spacing: Theme.cardSpacing) {
                        LimitStatCard(title: "日限额", window: report.daily)
                        LimitStatCard(title: "周限额", window: report.weekly)
                        NaturalMonthStatCard(summary: report.naturalMonthSummary())
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Theme.cardSpacing, alignment: .top),
                            GridItem(.flexible(), spacing: Theme.cardSpacing, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: 0
                    ) {
                        TodayCard(report: report)
                        TrendCard(days: report.days)
                    }

                    ModelStatsCard(models: report.models)

                    if let expiresAt = report.expiresAt {
                        FootnoteRow(
                            text: "套餐到期：\(sub2apiExpiryFormatter.string(from: expiresAt))",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                }

                ForEach(failedAccounts, id: \.id) { account in
                    InlineBanner(text: "\(account.name)：\(account.error ?? "刷新失败")")
                }

                if let message = errorText ?? agent.lastError {
                    InlineBanner(text: message)
                }

                FootnoteRow(text: "主数值为实际扣费(actual_cost)，与限额同口径；桌面组件每 2 分钟读取快照")
            }
            .padding(Theme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Sub2API 统计")
        .navigationSubtitle(snapshot.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0.generatedAt))" } ?? "未刷新")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshButton(isRefreshing: isRefreshing) { await refresh() }
            }
        }
        .onAppear {
            loadAccounts()
            loadSnapshot()
            agent.refreshStatus()
            if snapshot == nil && !accounts.isEmpty {
                Task { await refresh() }
            }
        }
        .onReceive(refreshTimer) { _ in
            Task { await refresh() }
        }
    }

    // MARK: - Scopes

    private var reports: [Sub2APIAccountReport] {
        snapshot?.accounts ?? []
    }

    private var failedAccounts: [Sub2APIAccountReport] {
        reports.filter { $0.error != nil }
    }

    private var scopeOptions: [(id: String, title: String)] {
        guard reports.count > 1 else {
            return reports.map { ($0.id, $0.name) }
        }
        return [("overview", "总览")] + reports.map { ($0.id, $0.name) }
    }

    private var selectedReport: Sub2APIAccountReport? {
        guard let snapshot, !snapshot.accounts.isEmpty else { return nil }
        if snapshot.accounts.count == 1 { return snapshot.accounts[0] }
        if selectedScopeID == "overview" { return snapshot.overview }
        return snapshot.accounts.first { $0.id == selectedScopeID } ?? snapshot.overview
    }

    // MARK: - Accounts card

    private var accountsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("账号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !isEditingAccount {
                    Button("添加账号") { beginAdd() }
                        .controlSize(.small)
                }
            }

            if accounts.isEmpty && !isEditingAccount {
                Text("尚未配置账号。添加中转站的 Base URL 和 API Key 后即可统计。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(accounts) { account in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName(account))
                            .font(.callout.weight(.medium))
                        Text("\(account.baseURL) · Key 已保存并隐藏")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("修改") { beginEdit(account) }
                        .controlSize(.small)
                        .disabled(isEditingAccount)
                    Button("删除", role: .destructive) { remove(account) }
                        .controlSize(.small)
                        .disabled(isEditingAccount)
                }
                .padding(.vertical, 2)
            }

            if isEditingAccount {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    TextField("显示名称（可选，默认用域名）", text: $formName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Base URL，例如 https://sub2api.jntm.us", text: $formBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                    TextField(
                        editingAccountID == nil ? "API Key（sk-…）" : "API Key（留空保持不变）",
                        text: $formApiKey
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                    HStack(spacing: 8) {
                        Button("保存") { saveAccountForm() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!formIsSavable)
                        Button("取消") { cancelEdit() }
                            .controlSize(.small)
                        Spacer()
                    }
                }
            }

            if let accountStatus {
                Text(accountStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
    }

    private func displayName(_ account: Sub2APIAccountEntry) -> String {
        let trimmed = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return URL(string: account.baseURL)?.host ?? account.baseURL
    }

    private var formIsSavable: Bool {
        let baseURL = formBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty else { return false }
        if editingAccountID == nil {
            return !formApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func beginAdd() {
        editingAccountID = nil
        formName = ""
        formBaseURL = ""
        formApiKey = ""
        accountStatus = nil
        isEditingAccount = true
    }

    private func beginEdit(_ account: Sub2APIAccountEntry) {
        editingAccountID = account.id
        formName = account.name
        formBaseURL = account.baseURL
        formApiKey = ""  // never re-display the stored key; empty = keep it
        accountStatus = nil
        isEditingAccount = true
    }

    private func cancelEdit() {
        isEditingAccount = false
        editingAccountID = nil
        formApiKey = ""
        accountStatus = nil
    }

    private func saveAccountForm() {
        let name = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = formBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = formApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        var updated = accounts
        if let editingAccountID, let index = updated.firstIndex(where: { $0.id == editingAccountID }) {
            updated[index].name = name
            updated[index].baseURL = baseURL
            if !apiKey.isEmpty {
                updated[index].apiKey = apiKey
            }
        } else {
            updated.append(Sub2APIAccountEntry(
                id: Sub2APIAccountEntry.makeID(),
                name: name,
                baseURL: baseURL,
                apiKey: apiKey
            ))
        }
        persist(accounts: updated, status: "已保存")
        if accountStatus == "已保存" {
            formApiKey = ""  // drop the plaintext from memory / view
            isEditingAccount = false
            editingAccountID = nil
            Task { await refresh() }
        }
    }

    private func remove(_ account: Sub2APIAccountEntry) {
        persist(accounts: accounts.filter { $0.id != account.id }, status: "已删除")
        if accountStatus == "已删除" {
            Task { await refresh() }
        }
    }

    private func persist(accounts updated: [Sub2APIAccountEntry], status: String) {
        var config = RuntimeConfigStore.load()  // preserve proxy / hosts / GLM key
        config.sub2apiAccounts = updated
        do {
            try RuntimeConfigStore.save(config)
            accounts = updated
            accountStatus = status
        } catch {
            accountStatus = "保存失败：\(error.localizedDescription)"
        }
    }

    private func loadAccounts() {
        accounts = RuntimeConfigStore.load().sub2apiAccounts
    }

    // MARK: - Snapshot

    private func loadSnapshot() {
        let state = loadQuotaPanelSnapshot(from: Sub2APIQuotaSnapshotStore())
        snapshot = state.snapshot
        errorText = state.errorText
        normalizeSelectedScope()
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let state = await refreshQuotaPanelSnapshot(
            store: Sub2APIQuotaSnapshotStore(),
            currentSnapshot: snapshot,
            fallbackReason: "未返回账号数据"
        ) {
            Sub2APIQuotaCollector().collect()
        }
        snapshot = state.snapshot
        errorText = state.errorText
        normalizeSelectedScope()
    }

    private func normalizeSelectedScope() {
        let ids = Set(scopeOptions.map(\.id))
        if !ids.contains(selectedScopeID) {
            selectedScopeID = scopeOptions.first?.id ?? "overview"
        }
    }
}

// MARK: - Limit cards

/// One of the relay's three spending limits, styled like QuotaStatCard but
/// with USD amounts instead of a reset time.
private struct LimitStatCard: View {
    let title: String
    let window: Sub2APILimitWindow?

    private var tone: QuotaTone { QuotaTone.from(remainingPercent: window?.remainingPercent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(window.map { "\($0.remainingPercent)%" } ?? "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(tone.color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let window {
                    Text("已用 \(window.usedPercent)%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            ProgressBar(remainingPercent: window?.remainingPercent, tone: tone)

            HStack {
                Text(window.map { "已用 \(sub2apiCostText($0.usageUSD))" } ?? "--")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(window.map { "剩 \(sub2apiCostText($0.remainingUSD)) / \(sub2apiLimitText($0.limitUSD))" } ?? "")
                    .foregroundStyle(.primary)
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .cardSurface()
    }
}

private struct NaturalMonthStatCard: View {
    let summary: Sub2APITokenSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自然月总额")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(sub2apiCostText(summary.actualCost))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("标准 \(sub2apiCostText(summary.cost))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                NaturalMonthMetric(label: "请求", value: "\(summary.requests) 次")
                NaturalMonthMetric(label: "Tokens", value: sub2apiCompactNumber(summary.totalTokens))
            }

            Text("按 daily_usage 汇总当前自然月")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .cardSurface()
    }
}

private struct NaturalMonthMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Today card

private struct TodayCard: View {
    var report: Sub2APIAccountReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sub2apiCostText(report.today.actualCost))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("标准 \(sub2apiCostText(report.today.cost))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text("\(report.today.requests) 次请求 · \(sub2apiCompactNumber(report.today.totalTokens)) tokens")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.cardSpacing) {
                TokenValue(label: "输入", value: report.today.inputTokens)
                TokenValue(label: "输出", value: report.today.outputTokens)
                TokenValue(label: "缓存写", value: report.today.cacheCreationTokens)
                TokenValue(label: "缓存读", value: report.today.cacheReadTokens)
            }

            Divider()

            HStack(spacing: Theme.cardSpacing) {
                TotalTile(title: "累计消耗", primary: sub2apiCostText(report.total.actualCost), secondary: "标准 \(sub2apiCostText(report.total.cost))")
                TotalTile(
                    title: "账户余量",
                    primary: report.remainingUSD.map(sub2apiCostText) ?? "--",
                    secondary: "\(sub2apiCompactNumber(report.total.totalTokens)) tokens 累计"
                )
            }
        }
        .cardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TokenValue: View {
    var label: String
    var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(sub2apiCompactNumber(value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TotalTile: View {
    var title: String
    var primary: String
    var secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(primary)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(secondary)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Trend card

/// Trailing 7 local days from the relay's daily_usage, zero-filled; bars use
/// actual cost like the rest of the panel.
private struct TrendCard: View {
    var days: [Sub2APIDayUsage]

    private var weekDays: [Sub2APIDayUsage] {
        let byPeriod = Dictionary(days.map { ($0.period, $0.summary) }, uniquingKeysWith: { a, _ in a })
        return (0..<7).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let period = sub2apiDayFormatter.string(from: date)
            return Sub2APIDayUsage(period: period, summary: byPeriod[period] ?? Sub2APITokenSummary())
        }
    }

    var body: some View {
        let weekDays = weekDays
        let maxCost = max(weekDays.map(\.summary.actualCost).max() ?? 0, 0.01)
        let elapsed = weekDays.map(\.summary.actualCost)
        let average = elapsed.isEmpty ? 0 : elapsed.reduce(0, +) / Double(elapsed.count)
        let todayPeriod = sub2apiDayFormatter.string(from: Date())

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近 7 天趋势")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("均值 \(sub2apiCostText(average))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 5) {
                // The bar area stretches to whatever height the card gets from
                // the grid row (the today card is usually taller), so bars are
                // sized from the measured height instead of a fixed constant.
                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        let y = geo.size.height * (1 - CGFloat(average / maxCost))
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(weekDays) { day in
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.indigo.opacity(0.35 + 0.6 * (day.summary.actualCost / maxCost)))
                                        .frame(height: max(4, geo.size.height * day.summary.actualCost / maxCost))
                                        .overlay {
                                            if day.period == todayPeriod {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 88, maxHeight: .infinity)

                HStack(spacing: 8) {
                    ForEach(weekDays) { day in
                        VStack(spacing: 1) {
                            Text(sub2apiWeekdayShort(day.period))
                                .font(.system(size: 10, weight: day.period == todayPeriod ? .semibold : .regular))
                                .foregroundStyle(day.period == todayPeriod ? Color.primary : Color.secondary)
                            Text(sub2apiCostText(day.summary.actualCost))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

// MARK: - Model stats card

private struct ModelStatsCard: View {
    var models: [Sub2APIModelStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("模型明细")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("累计口径")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if models.isEmpty {
                Text("暂无模型数据")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                let totalCost = models.reduce(0) { $0 + $1.summary.actualCost }
                ForEach(models.prefix(8)) { model in
                    let percent = totalCost > 0 ? model.summary.actualCost / totalCost * 100 : 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(model.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(sub2apiCostText(model.summary.actualCost)) · \(String(format: "%.1f", percent))% · \(model.summary.requests) 次 · \(sub2apiCompactNumber(model.summary.totalTokens)) tokens")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.14))
                                Capsule()
                                    .fill(Color.indigo.opacity(0.7))
                                    .frame(width: geo.size.width * min(1, max(0, percent / 100)))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

// MARK: - Formatting

private func sub2apiCostText(_ value: Double) -> String {
    String(format: "$%.2f", value)
}

/// Limits are round numbers ($160 / $800); drop the cents.
private func sub2apiLimitText(_ value: Double) -> String {
    value == value.rounded() ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
}

private func sub2apiCompactNumber(_ value: Int) -> String {
    let number = Double(value)
    if number >= 1_000_000_000 {
        return String(format: "%.1fB", number / 1_000_000_000)
    }
    if number >= 1_000_000 {
        return String(format: "%.1fM", number / 1_000_000)
    }
    if number >= 1_000 {
        return String(format: "%.1fK", number / 1_000)
    }
    return "\(value)"
}

private func sub2apiWeekdayShort(_ period: String) -> String {
    guard let date = sub2apiDayFormatter.date(from: period) else { return "" }
    let index = Calendar.current.component(.weekday, from: date)
    let labels = ["日", "一", "二", "三", "四", "五", "六"]
    return labels[max(0, min(6, index - 1))]
}

private let sub2apiDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let sub2apiExpiryFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()
