import Foundation
import Testing

@testable import Sub2APIQuotaCore

/// Real `/v1/usage` response shape from a sub2api relay (values trimmed).
private let sampleJSON = """
{"daily_usage":[{"date":"2026-07-05","requests":3,"input_tokens":34661,"output_tokens":131,"cache_read_tokens":22272,"cache_write_tokens":100,"total_tokens":57164,"cost":0.1488911,"actual_cost":0.07444555}],
"isValid":true,"mode":"unrestricted",
"model_stats":[{"model":"gpt-5.5","requests":1,"input_tokens":24239,"output_tokens":29,"cache_creation_tokens":0,"cache_read_tokens":9600,"total_tokens":33868,"cost":0.126865,"actual_cost":0.0634325},
{"model":"gpt-5.4","requests":1,"input_tokens":6424,"output_tokens":14,"cache_creation_tokens":0,"cache_read_tokens":8064,"total_tokens":14502,"cost":0.018286,"actual_cost":0.009143}],
"planName":"👑 GPT Pro 按量统计","remaining":159.92555445,
"subscription":{"daily_limit_usd":160,"daily_usage_usd":0.07444555,"expires_at":"2027-04-30T17:09:43.320667+08:00","monthly_limit_usd":3000,"monthly_usage_usd":0.07444555,"weekly_limit_usd":800,"weekly_usage_usd":0.07444555},
"unit":"USD",
"usage":{"average_duration_ms":6312.6,"rpm":0,"today":{"actual_cost":0.07444555,"cache_creation_tokens":0,"cache_read_tokens":22272,"cost":0.1488911,"input_tokens":34661,"output_tokens":131,"requests":3,"total_tokens":57064},"total":{"actual_cost":0.07444555,"cache_creation_tokens":0,"cache_read_tokens":22272,"cost":0.1488911,"input_tokens":34661,"output_tokens":131,"requests":3,"total_tokens":57064},"tpm":0}}
"""

@Test func parsesUsageResponse() throws {
    let report = try Sub2APIQuotaCollector.parseResponse(sampleJSON)

    #expect(report.planName == "👑 GPT Pro 按量统计")
    #expect(report.mode == "unrestricted")
    #expect(report.remainingUSD == 159.92555445)
    #expect(report.expiresAt != nil)

    #expect(report.daily?.limitUSD == 160)
    #expect(report.daily?.usageUSD == 0.07444555)
    #expect(report.weekly?.limitUSD == 800)
    #expect(report.monthly?.limitUSD == 3000)
    #expect(report.daily?.usedPercent == 0)
    #expect(report.daily?.remainingPercent == 100)

    #expect(report.today.requests == 3)
    #expect(report.today.totalTokens == 57064)
    #expect(report.today.cost == 0.1488911)
    #expect(report.today.actualCost == 0.07444555)

    // daily_usage uses `cache_write_tokens`; must land in cacheCreationTokens.
    #expect(report.days.count == 1)
    #expect(report.days[0].period == "2026-07-05")
    #expect(report.days[0].summary.cacheCreationTokens == 100)

    // model_stats uses `cache_creation_tokens`, sorted by actual cost.
    #expect(report.models.map(\.name) == ["gpt-5.5", "gpt-5.4"])
    #expect(report.models[0].summary.cacheReadTokens == 9600)
}

@Test func invalidKeyResponseThrows() {
    let body = #"{"isValid":false,"mode":"unrestricted"}"#
    #expect(throws: Sub2APIQuotaError.self) {
        try Sub2APIQuotaCollector.parseResponse(body)
    }
}

@Test func errorEnvelopeSurfacesMessage() {
    let body = #"{"error":{"message":"invalid api key","type":"auth"}}"#
    do {
        _ = try Sub2APIQuotaCollector.parseResponse(body)
        Issue.record("expected an error")
    } catch {
        #expect(error.localizedDescription.contains("invalid api key"))
    }
}

@Test func normalizesBaseURL() {
    #expect(Sub2APIQuotaCollector.usageURL(baseURL: "https://x.y") == "https://x.y/v1/usage")
    #expect(Sub2APIQuotaCollector.usageURL(baseURL: "https://x.y/") == "https://x.y/v1/usage")
    #expect(Sub2APIQuotaCollector.usageURL(baseURL: "https://x.y/v1") == "https://x.y/v1/usage")
    #expect(Sub2APIQuotaCollector.usageURL(baseURL: " https://x.y/v1/ ") == "https://x.y/v1/usage")
}

@Test func overviewAggregatesAccounts() throws {
    var first = try Sub2APIQuotaCollector.parseResponse(sampleJSON)
    first.id = "a"
    first.name = "A"
    var second = try Sub2APIQuotaCollector.parseResponse(sampleJSON)
    second.id = "b"
    second.name = "B"
    let failed = Sub2APIAccountReport(id: "c", name: "C", error: "boom")

    let snapshot = Sub2APISnapshot(generatedAt: Date(), accounts: [first, second, failed])
    let overview = snapshot.overview

    #expect(overview.daily?.limitUSD == 320)
    #expect(overview.today.requests == 6)
    #expect(overview.today.cost == 0.1488911 * 2)
    #expect(overview.days.count == 1)
    #expect(overview.days[0].summary.totalTokens == 57164 * 2)
    #expect(overview.models.count == 2)
    #expect(overview.models[0].summary.requests == 2)
}

@Test func snapshotRoundTripsThroughCodable() throws {
    let report = try Sub2APIQuotaCollector.parseResponse(sampleJSON)
    let snapshot = Sub2APISnapshot(generatedAt: Date(), accounts: [report])
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(Sub2APISnapshot.self, from: data)
    #expect(decoded == snapshot)
}

@Test func naturalMonthSummaryUsesCurrentCalendarMonth() {
    let report = Sub2APIAccountReport(
        id: "a",
        name: "A",
        days: [
            Sub2APIDayUsage(
                period: "2026-07-01",
                summary: Sub2APITokenSummary(requests: 2, totalTokens: 100, cost: 2, actualCost: 1)
            ),
            Sub2APIDayUsage(
                period: "2026-07-15",
                summary: Sub2APITokenSummary(requests: 3, totalTokens: 250, cost: 4, actualCost: 2)
            ),
            Sub2APIDayUsage(
                period: "2026-06-30",
                summary: Sub2APITokenSummary(requests: 9, totalTokens: 999, cost: 9, actualCost: 9)
            )
        ]
    )

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!

    let summary = report.naturalMonthSummary(now: now, calendar: calendar)
    #expect(summary.requests == 5)
    #expect(summary.totalTokens == 350)
    #expect(summary.cost == 6)
    #expect(summary.actualCost == 3)
}
