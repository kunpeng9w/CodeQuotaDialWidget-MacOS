import Foundation

/// Token/cost totals for one slice of sub2api usage (a day, a model, or a
/// today/total block). `cost` is the upstream list price; `actualCost` is what
/// the relay actually charged (the limits are counted against `actualCost`).
public struct Sub2APITokenSummary: Codable, Equatable, Sendable {
    public var requests: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationTokens: Int
    public var cacheReadTokens: Int
    public var totalTokens: Int
    public var cost: Double
    public var actualCost: Double

    public init(
        requests: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        totalTokens: Int = 0,
        cost: Double = 0,
        actualCost: Double = 0
    ) {
        self.requests = requests
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = totalTokens
        self.cost = cost
        self.actualCost = actualCost
    }

    public static func + (lhs: Sub2APITokenSummary, rhs: Sub2APITokenSummary) -> Sub2APITokenSummary {
        Sub2APITokenSummary(
            requests: lhs.requests + rhs.requests,
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            cost: lhs.cost + rhs.cost,
            actualCost: lhs.actualCost + rhs.actualCost
        )
    }
}

/// One of the relay's spending limits (daily / weekly / monthly), in USD.
public struct Sub2APILimitWindow: Codable, Equatable, Sendable {
    public var limitUSD: Double
    public var usageUSD: Double

    public init(limitUSD: Double, usageUSD: Double) {
        self.limitUSD = limitUSD
        self.usageUSD = usageUSD
    }

    public var remainingUSD: Double { max(0, limitUSD - usageUSD) }

    public var usedPercent: Int {
        guard limitUSD > 0 else { return 0 }
        return min(100, max(0, Int((usageUSD / limitUSD * 100).rounded())))
    }

    public var remainingPercent: Int { 100 - usedPercent }

    public static func + (lhs: Sub2APILimitWindow, rhs: Sub2APILimitWindow) -> Sub2APILimitWindow {
        Sub2APILimitWindow(limitUSD: lhs.limitUSD + rhs.limitUSD, usageUSD: lhs.usageUSD + rhs.usageUSD)
    }
}

/// One day from the relay's `daily_usage` array. `period` is the server-side
/// day key, "yyyy-MM-dd".
public struct Sub2APIDayUsage: Codable, Equatable, Sendable, Identifiable {
    public var period: String
    public var summary: Sub2APITokenSummary

    public var id: String { period }

    public init(period: String, summary: Sub2APITokenSummary) {
        self.period = period
        self.summary = summary
    }
}

/// One row from the relay's cumulative `model_stats` array.
public struct Sub2APIModelStat: Codable, Equatable, Sendable, Identifiable {
    public var name: String
    public var summary: Sub2APITokenSummary

    public var id: String { name }

    public init(name: String, summary: Sub2APITokenSummary) {
        self.name = name
        self.summary = summary
    }
}

/// Everything `/v1/usage` reports for a single configured account. A fetch or
/// parse failure keeps the account in the snapshot with only `error` set, so
/// one bad key never hides the others.
public struct Sub2APIAccountReport: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var planName: String?
    public var mode: String?
    public var remainingUSD: Double?
    public var expiresAt: Date?
    public var daily: Sub2APILimitWindow?
    public var weekly: Sub2APILimitWindow?
    public var monthly: Sub2APILimitWindow?
    public var today: Sub2APITokenSummary
    public var total: Sub2APITokenSummary
    public var days: [Sub2APIDayUsage]
    public var models: [Sub2APIModelStat]
    public var error: String?

    public init(
        id: String,
        name: String,
        planName: String? = nil,
        mode: String? = nil,
        remainingUSD: Double? = nil,
        expiresAt: Date? = nil,
        daily: Sub2APILimitWindow? = nil,
        weekly: Sub2APILimitWindow? = nil,
        monthly: Sub2APILimitWindow? = nil,
        today: Sub2APITokenSummary = Sub2APITokenSummary(),
        total: Sub2APITokenSummary = Sub2APITokenSummary(),
        days: [Sub2APIDayUsage] = [],
        models: [Sub2APIModelStat] = [],
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.planName = planName
        self.mode = mode
        self.remainingUSD = remainingUSD
        self.expiresAt = expiresAt
        self.daily = daily
        self.weekly = weekly
        self.monthly = monthly
        self.today = today
        self.total = total
        self.days = days
        self.models = models
        self.error = error
    }
}

public struct Sub2APISnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var accounts: [Sub2APIAccountReport]
    public var error: String?

    public init(generatedAt: Date, accounts: [Sub2APIAccountReport] = [], error: String? = nil) {
        self.generatedAt = generatedAt
        self.accounts = accounts
        self.error = error
    }

    /// `error` is only set when nothing usable came back (no accounts
    /// configured, or every account failed); partial failures are carried in
    /// the per-account `error` fields and still count as a successful refresh.
    public var isRefreshFailure: Bool { error != nil }

    /// Cross-account aggregate for the "总览" scope: sums money and limits,
    /// merges days by period and models by name.
    public var overview: Sub2APIAccountReport {
        let reachable = accounts.filter { $0.error == nil }

        var byPeriod: [String: Sub2APITokenSummary] = [:]
        var byModel: [String: Sub2APITokenSummary] = [:]
        for account in reachable {
            for day in account.days {
                byPeriod[day.period, default: Sub2APITokenSummary()] = byPeriod[day.period, default: Sub2APITokenSummary()] + day.summary
            }
            for model in account.models {
                byModel[model.name, default: Sub2APITokenSummary()] = byModel[model.name, default: Sub2APITokenSummary()] + model.summary
            }
        }

        return Sub2APIAccountReport(
            id: "overview",
            name: "总览",
            planName: reachable.count == 1 ? reachable[0].planName : nil,
            mode: reachable.count == 1 ? reachable[0].mode : nil,
            remainingUSD: Self.sumIfAny(reachable.map(\.remainingUSD)),
            expiresAt: reachable.count == 1 ? reachable[0].expiresAt : nil,
            daily: Self.sumIfAny(reachable.map(\.daily)),
            weekly: Self.sumIfAny(reachable.map(\.weekly)),
            monthly: Self.sumIfAny(reachable.map(\.monthly)),
            today: reachable.reduce(Sub2APITokenSummary()) { $0 + $1.today },
            total: reachable.reduce(Sub2APITokenSummary()) { $0 + $1.total },
            days: byPeriod.keys.sorted().map { Sub2APIDayUsage(period: $0, summary: byPeriod[$0]!) },
            models: byModel
                .map { Sub2APIModelStat(name: $0.key, summary: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.summary.actualCost == rhs.summary.actualCost { return lhs.name < rhs.name }
                    return lhs.summary.actualCost > rhs.summary.actualCost
                }
        )
    }

    private static func sumIfAny(_ values: [Double?]) -> Double? {
        let present = values.compactMap { $0 }
        return present.isEmpty ? nil : present.reduce(0, +)
    }

    private static func sumIfAny(_ windows: [Sub2APILimitWindow?]) -> Sub2APILimitWindow? {
        let present = windows.compactMap { $0 }
        guard let first = present.first else { return nil }
        return present.dropFirst().reduce(first, +)
    }
}
