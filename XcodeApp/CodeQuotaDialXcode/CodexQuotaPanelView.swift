import CodexQuotaCore
import SwiftUI
import WidgetKit

struct CodexQuotaPanelView: View {
    @State private var snapshot: CodexQuotaSnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.codex.label,
        plistPath: LaunchAgentLabels.codex.plist
    )

    var body: some View {
        PanelScaffold(
            section: .codex,
            updatedAt: snapshot?.generatedAt,
            badges: snapshot?.planType.map {
                [PanelBadge(text: $0.uppercased(), tint: .teal, muted: snapshot?.isFreePlan ?? false)]
            } ?? [],
            agent: agent,
            errorText: errorText ?? agent.lastError
        ) {
            if let monthly = snapshot?.monthly, snapshot?.fiveHour == nil {
                // 免费版：单个 30 天额度表盘。
                QuotaGaugeCard(title: "30 天额度", model: QuotaStatModel(monthly))
            } else {
                HStack(spacing: DS.Space.s) {
                    QuotaGaugeCard(title: "5h", model: QuotaStatModel(snapshot?.fiveHour))
                    QuotaGaugeCard(title: "本周", model: QuotaStatModel(snapshot?.weekly))
                }
            }

            FootnoteRow(text: "桌面组件每 2 分钟读取快照")
        }
        .navigationTitle("Codex 额度")
        .navigationSubtitle(snapshot.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0.generatedAt))" } ?? "未刷新")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshButton(isRefreshing: isRefreshing) { await refresh() }
            }
        }
        .onAppear {
            loadSnapshot()
            agent.refreshStatus()
        }
    }

    private func loadSnapshot() {
        let state = loadQuotaPanelSnapshot(from: CodexQuotaSnapshotStore())
        snapshot = state.snapshot
        errorText = state.errorText
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let state = await refreshQuotaPanelSnapshot(
            store: CodexQuotaSnapshotStore(),
            currentSnapshot: snapshot,
            fallbackReason: "未返回额度窗口"
        ) {
            CodexQuotaCollector().collect()
        }
        snapshot = state.snapshot
        errorText = state.errorText
    }
}

extension QuotaStatModel {
    init(_ window: CodexQuotaWindow?) {
        self.init(
            remainingPercent: window?.remainingPercent,
            usedPercent: window?.usedPercent,
            absoluteText: nil,
            resetsAt: window?.resetsAt
        )
    }
}
