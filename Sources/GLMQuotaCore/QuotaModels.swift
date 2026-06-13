import Foundation

public struct GLMQuotaSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var timeLimit: GLMQuotaWindow?
    public var tokensLimit5: GLMQuotaWindow?
    public var tokensLimitMonth: GLMQuotaWindow?
    public var level: String?
    public var error: String?

    public init(
        generatedAt: Date,
        timeLimit: GLMQuotaWindow? = nil,
        tokensLimit5: GLMQuotaWindow? = nil,
        tokensLimitMonth: GLMQuotaWindow? = nil,
        level: String? = nil,
        error: String? = nil
    ) {
        self.generatedAt = generatedAt
        self.timeLimit = timeLimit
        self.tokensLimit5 = tokensLimit5
        self.tokensLimitMonth = tokensLimitMonth
        self.level = level
        self.error = error
    }

    public var hasCompleteDisplayData: Bool {
        timeLimit != nil && tokensLimit5 != nil && tokensLimitMonth != nil
    }

    public var isRefreshFailure: Bool {
        error != nil || !hasCompleteDisplayData
    }
}

public struct GLMQuotaWindow: Codable, Equatable, Sendable {
    public var remainingPercent: Int
    public var usedPercent: Int
    public var resetsAt: Date?
    public var usage: Int?
    public var remaining: Int?
    public var total: Int?

    public init(
        remainingPercent: Int = 0,
        usedPercent: Int = 0,
        resetsAt: Date? = nil,
        usage: Int? = nil,
        remaining: Int? = nil,
        total: Int? = nil
    ) {
        self.remainingPercent = remainingPercent
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.usage = usage
        self.remaining = remaining
        self.total = total
    }
}
