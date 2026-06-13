import Foundation
import Testing

@testable import CodexQuotaCore

@Test func parsesFiveHourAndWeeklyLimits() throws {
    let stdout = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":27,"resetsAt":1760000000,"windowDurationMins":300},"secondary":{"usedPercent":42,"resetsAt":1760400000,"windowDurationMins":10080}}}}
    """

    let snapshot = try CodexQuotaCollector.parseRateLimitsResponse(stdout)

    #expect(snapshot.fiveHour?.remainingPercent == 73)
    #expect(snapshot.fiveHour?.usedPercent == 27)
    #expect(snapshot.weekly?.remainingPercent == 58)
    #expect(snapshot.weekly?.usedPercent == 42)
}

@Test func clampsRemainingPercent() throws {
    let stdout = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":115,"windowDurationMins":300},"secondary":{"usedPercent":-8,"windowDurationMins":10080}}}}
    """

    let snapshot = try CodexQuotaCollector.parseRateLimitsResponse(stdout)

    #expect(snapshot.fiveHour?.remainingPercent == 0)
    #expect(snapshot.weekly?.remainingPercent == 100)
}

@Test func marksErrorOrEmptySnapshotsAsRefreshFailures() {
    let errorSnapshot = CodexQuotaSnapshot(generatedAt: Date(), error: "network failed")
    let emptySnapshot = CodexQuotaSnapshot(generatedAt: Date())
    let validSnapshot = CodexQuotaSnapshot(
        generatedAt: Date(),
        fiveHour: CodexQuotaWindow(remainingPercent: 70),
        weekly: CodexQuotaWindow(remainingPercent: 40)
    )
    let partialSnapshot = CodexQuotaSnapshot(
        generatedAt: Date(),
        fiveHour: CodexQuotaWindow(remainingPercent: 70)
    )

    #expect(errorSnapshot.isRefreshFailure)
    #expect(emptySnapshot.isRefreshFailure)
    #expect(partialSnapshot.isRefreshFailure)
    #expect(!validSnapshot.isRefreshFailure)
}
