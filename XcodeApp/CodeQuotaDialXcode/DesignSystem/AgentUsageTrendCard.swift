import SwiftUI
import UsageQuotaCore

/// provider 面板底部的「本周消耗」卡：从消耗统计快照读取该 provider 对应
/// agent 的数据（与消耗统计面板同源），填充表盘行下方的空白。
/// 快照里找不到对应 agent 时整卡隐藏；onAppear 只读快照，不触发采集。
struct AgentUsageTrendCard: View {
    /// usage 快照里的 agent 名（如 "codex" / "claude" / "zcode"）。
    let agentName: String
    /// 卡标题里的显示名，缺省用 agent 名首字母大写。
    var displayName: String?
    var tint: Color = .blue

    @State private var agent: UsageAgentSnapshot?

    var body: some View {
        content
            .onAppear(perform: load)
    }

    @ViewBuilder private var content: some View {
        if let agent {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                DSSectionHeader(
                    "本周消耗 · \(displayName ?? agent.name.capitalized)",
                    subtitle: "今日 \(dsCost(agent.daily.totalCost)) · 本周 \(dsCost(agent.weekly.totalCost))"
                )
                DSTrendChart(
                    days: agent.weekDays.map { .init(period: $0.period, value: $0.totalCost) },
                    tint: tint
                )
            }
            .dsCard()
        } else {
            // 空分支必须是真实视图，否则 onAppear 不触发、永远加载不到数据。
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func load() {
        guard let snapshot = try? UsageSnapshotStore().load() else {
            agent = nil
            return
        }
        // 先在顶层 agents 找；多端模式下退回各 host 聚合的同名 agent。
        let name = agentName.lowercased()
        agent = snapshot.agents.first { $0.name.lowercased() == name }
            ?? snapshot.hosts.flatMap(\.agents).first { $0.name.lowercased() == name }
    }
}
