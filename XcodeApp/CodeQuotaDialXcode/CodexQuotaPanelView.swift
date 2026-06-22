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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                if let plan = snapshot?.planType {
                    let isFree = snapshot?.isFreePlan ?? false
                    TagBadge(text: plan.uppercased(), tint: .teal, muted: isFree)
                }

                LaunchAgentToggleRow(controller: agent)

                if let monthly = snapshot?.monthly, snapshot?.fiveHour == nil {
                    // 免费版：单个 30 天额度表盘。
                    QuotaStatCard(title: "30 天额度", model: QuotaStatModel(monthly))
                } else {
                    HStack(spacing: Theme.cardSpacing) {
                        QuotaStatCard(title: "5h", model: QuotaStatModel(snapshot?.fiveHour))
                        QuotaStatCard(title: "本周", model: QuotaStatModel(snapshot?.weekly))
                    }
                }

                if let message = errorText ?? agent.lastError {
                    InlineBanner(text: message)
                }

                FootnoteRow(text: "桌面组件每 2 分钟读取快照")
            }
            .padding(Theme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
