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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                if snapshot?.planType != nil || snapshot?.email != nil {
                    HStack(spacing: 8) {
                        if let planType = snapshot?.planType {
                            TagBadge(text: planType.uppercased(), tint: .purple)
                        }
                        if let email = snapshot?.email {
                            Text(email)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LaunchAgentToggleRow(controller: agent)

                HStack(spacing: Theme.cardSpacing) {
                    ForEach(AntigravityQuotaBucket.allCases, id: \.self) { bucket in
                        QuotaStatCard(
                            title: bucket.displayName,
                            model: QuotaStatModel(snapshot?.model(for: bucket))
                        )
                    }
                }

                if let message = errorText ?? agent.lastError {
                    InlineBanner(text: message)
                }

                FootnoteRow(text: "需要本机 Antigravity 正在运行")
            }
            .padding(Theme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
