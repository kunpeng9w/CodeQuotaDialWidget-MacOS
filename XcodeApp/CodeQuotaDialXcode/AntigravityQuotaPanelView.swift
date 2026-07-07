import AntigravityQuotaCore
import SwiftUI
import WidgetKit

struct AntigravityQuotaPanelView: View {
    @State private var snapshot: AntigravityQuotaSnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.antigravity.label,
        plistPath: LaunchAgentLabels.antigravity.plist
    )

    var body: some View {
        PanelScaffold(
            section: .antigravity,
            updatedAt: snapshot?.generatedAt,
            badges: snapshot?.planType.map { [PanelBadge(text: $0.uppercased(), tint: .purple)] } ?? [],
            statusLine: snapshot?.email,
            agent: agent,
            errorText: errorText ?? agent.lastError
        ) {
            // 固定两列：2 个 bucket 时与 Claude 面板的对半卡完全同宽，
            // 4 个 bucket 时 2×2（自适应网格会在宽窗排 3 列导致卡宽不一致）。
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Space.s, alignment: .top),
                    GridItem(.flexible(), spacing: DS.Space.s, alignment: .top),
                ],
                alignment: .leading,
                spacing: DS.Space.s
            ) {
                ForEach(AntigravityQuotaBucket.allCases, id: \.self) { bucket in
                    let model = QuotaStatModel(snapshot?.model(for: bucket))
                    QuotaGaugeCard(
                        title: bucket.displayName,
                        model: model,
                        detailLines: model.absoluteText.map { [$0] } ?? []
                    )
                }
            }

            FootnoteRow(text: "需要本机 Antigravity 正在运行")
        }
        .navigationTitle("Antigravity 额度")
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
        let state = loadQuotaPanelSnapshot(from: AntigravityQuotaSnapshotStore())
        snapshot = state.snapshot
        errorText = state.errorText
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let state = await refreshQuotaPanelSnapshot(
            store: AntigravityQuotaSnapshotStore(),
            currentSnapshot: snapshot,
            fallbackReason: "未返回目标模型额度"
        ) {
            AntigravityQuotaCollector().collect()
        }
        snapshot = state.snapshot
        errorText = state.errorText
    }
}

extension QuotaStatModel {
    init(_ model: AntigravityModelQuota?) {
        guard let model else {
            self.init(remainingPercent: nil, usedPercent: nil, absoluteText: nil, resetsAt: nil)
            return
        }
        self.init(
            remainingPercent: model.remainingPercent,
            usedPercent: model.usedPercent,
            absoluteText: model.label,
            resetsAt: model.resetsAt
        )
    }
}
