import Foundation

public struct CodexQuotaSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var fiveHour: CodexQuotaWindow?
    public var weekly: CodexQuotaWindow?
    public var error: String?

    public init(
        generatedAt: Date,
        fiveHour: CodexQuotaWindow? = nil,
        weekly: CodexQuotaWindow? = nil,
        error: String? = nil
    ) {
        self.generatedAt = generatedAt
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.error = error
    }

    public var hasCompleteDisplayData: Bool {
        fiveHour != nil && weekly != nil
    }

    public var isRefreshFailure: Bool {
        error != nil || !hasCompleteDisplayData
    }
}

public struct CodexQuotaWindow: Codable, Equatable, Sendable {
    public var remainingPercent: Int?
    public var usedPercent: Int?
    public var resetsAt: Date?
    public var windowDurationMins: Int?

    public init(
        remainingPercent: Int? = nil,
        usedPercent: Int? = nil,
        resetsAt: Date? = nil,
        windowDurationMins: Int? = nil
    ) {
        self.remainingPercent = remainingPercent
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowDurationMins = windowDurationMins
    }
}
