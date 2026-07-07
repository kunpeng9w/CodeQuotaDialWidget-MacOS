import ClaudeQuotaCore
import SwiftUI
import WidgetKit

struct ClaudeQuotaPanelView: View {
    @State private var snapshot: ClaudeQuotaSnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.claude.label,
        plistPath: LaunchAgentLabels.claude.plist
    )

    var body: some View {
        PanelScaffold(
            section: .claude,
            updatedAt: snapshot?.generatedAt,
            badges: snapshot?.planType.map { [PanelBadge(text: $0.uppercased(), tint: .orange)] } ?? [],
            agent: agent,
            errorText: errorText ?? agent.lastError
        ) {
            HStack(spacing: DS.Space.s) {
                QuotaGaugeCard(title: "5h", model: QuotaStatModel(snapshot?.fiveHour))
                QuotaGaugeCard(title: "本周", model: QuotaStatModel(snapshot?.weekly))
            }

            FootnoteRow(text: "桌面组件每 2 分钟读取快照")
        }
        .navigationTitle("Claude 额度")
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
        let state = loadQuotaPanelSnapshot(from: ClaudeQuotaSnapshotStore())
        snapshot = state.snapshot
        errorText = state.errorText
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let state = await refreshQuotaPanelSnapshot(
            store: ClaudeQuotaSnapshotStore(),
            currentSnapshot: snapshot,
            fallbackReason: "未返回额度窗口"
        ) {
            ClaudeQuotaCollector().collect()
        }
        snapshot = state.snapshot
        errorText = state.errorText
    }
}

extension QuotaStatModel {
    init(_ window: ClaudeQuotaWindow?) {
        self.init(
            remainingPercent: window?.remainingPercent,
            usedPercent: window?.usedPercent,
            absoluteText: nil,
            resetsAt: window?.resetsAt
        )
    }
}
