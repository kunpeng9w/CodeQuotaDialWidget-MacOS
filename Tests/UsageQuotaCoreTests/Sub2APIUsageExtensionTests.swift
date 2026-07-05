import Foundation
import Sub2APIQuotaCore
import Testing

@testable import UsageQuotaCore

@Suite struct Sub2APIUsageExtensionTests {
    private func day(_ period: String, cost: Double, actualCost: Double, tokens: Int) -> Sub2APIDayUsage {
        Sub2APIDayUsage(period: period, summary: Sub2APITokenSummary(
            requests: 1,
            inputTokens: tokens,
            totalTokens: tokens,
            cost: cost,
            actualCost: actualCost
        ))
    }

    @Test func usesStandardCostNotActualCost() {
        let snapshot = Sub2APISnapshot(generatedAt: Date(), accounts: [
            Sub2APIAccountReport(id: "a", name: "A", days: [day("2026-07-05", cost: 0.2, actualCost: 0.1, tokens: 100)])
        ])

        let rows = Sub2APIUsageExtension.dailyRows(from: snapshot)
        #expect(rows.count == 1)
        #expect(rows[0].summary.totalCost == 0.2)
        #expect(rows[0].agents == ["sub2api"])
        #expect(rows[0].models["sub2api"]?.totalCost == 0.2)
    }

    @Test func mergesAccountsByPeriodAndSkipsFailures() {
        let snapshot = Sub2APISnapshot(generatedAt: Date(), accounts: [
            Sub2APIAccountReport(id: "a", name: "A", days: [
                day("2026-07-04", cost: 1, actualCost: 0.5, tokens: 10),
                day("2026-07-05", cost: 2, actualCost: 1, tokens: 20)
            ]),
            Sub2APIAccountReport(id: "b", name: "B", days: [
                day("2026-07-05", cost: 3, actualCost: 1.5, tokens: 30)
            ]),
            Sub2APIAccountReport(id: "c", name: "C", days: [
                day("2026-07-05", cost: 100, actualCost: 50, tokens: 1000)
            ], error: "unreachable")
        ])

        let rows = Sub2APIUsageExtension.dailyRows(from: snapshot)
        #expect(rows.map(\.period) == ["2026-07-04", "2026-07-05"])
        #expect(rows[1].summary.totalCost == 5)
        #expect(rows[1].summary.totalTokens == 50)
    }
}
