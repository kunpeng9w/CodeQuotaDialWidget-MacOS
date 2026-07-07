import Foundation
import Testing

@testable import UsagePanelSupport

@Test func primaryWindowIsTheMostConstrainedOne() {
    #expect(OverviewSummaryLogic.primaryRemainingPercent([91, 34]) == 34)
    #expect(OverviewSummaryLogic.primaryRemainingPercent([nil, 62, nil, 83]) == 62)
    #expect(OverviewSummaryLogic.primaryRemainingPercent([nil, nil]) == nil)
    #expect(OverviewSummaryLogic.primaryRemainingPercent([]) == nil)
}

@Test func staleCutoffIsThirtyMinutes() {
    let now = ISO8601DateFormatter().date(from: "2026-07-07T12:00:00Z")!
    let fresh = ISO8601DateFormatter().date(from: "2026-07-07T11:31:00Z")!
    let stale = ISO8601DateFormatter().date(from: "2026-07-07T11:29:00Z")!

    #expect(!OverviewSummaryLogic.isStale(generatedAt: fresh, now: now))
    #expect(OverviewSummaryLogic.isStale(generatedAt: stale, now: now))
    #expect(!OverviewSummaryLogic.isStale(generatedAt: nil, now: now))
}
