import Foundation
import Sub2APIQuotaCore

/// Local-only extension that folds sub2api relay usage into the usage stats,
/// like the ZCode extension. Costs are counted at the upstream list price
/// (`cost`), not the relay's discounted `actual_cost` — the discounted figures
/// live in the dedicated Sub2API panel/widget instead.
struct Sub2APIUsageExtension: Sendable {
    static let agentName = "sub2api"

    struct Result: Sendable {
        var rows: [DailyRow] = []
    }

    func collect(now: Date) -> Result {
        guard UsageSub2APIConfig.enabled, !Sub2APIQuotaConfig.accounts().isEmpty else { return Result() }
        let snapshot = Sub2APIQuotaCollector().collect(now: now)
        return Result(rows: Self.dailyRows(from: snapshot))
    }

    /// Per-day rows across all accounts, priced at the standard `cost`. The
    /// relay reports no per-day model split, so each day is attributed to a
    /// single pseudo-model named after the agent.
    static func dailyRows(from snapshot: Sub2APISnapshot) -> [DailyRow] {
        var byPeriod: [String: UsageSummary] = [:]
        for account in snapshot.accounts where account.error == nil {
            for day in account.days {
                let summary = UsageSummary(
                    inputTokens: day.summary.inputTokens,
                    outputTokens: day.summary.outputTokens,
                    cacheCreationTokens: day.summary.cacheCreationTokens,
                    cacheReadTokens: day.summary.cacheReadTokens,
                    totalTokens: day.summary.totalTokens,
                    totalCost: day.summary.cost
                )
                guard summary.totalTokens > 0 || summary.totalCost > 0 else { continue }
                byPeriod[day.period, default: UsageSummary()] = byPeriod[day.period, default: UsageSummary()] + summary
            }
        }
        return byPeriod.keys.sorted().map { period in
            let summary = byPeriod[period]!
            return DailyRow(
                period: period,
                summary: summary,
                agents: [agentName],
                models: [agentName: summary]
            )
        }
    }
}
