import Foundation
import QuotaProcessSupport

public struct Sub2APIQuotaCollector: Sendable {

    public init() {}

    public func collect(now: Date = Date()) -> Sub2APISnapshot {
        let accounts = Sub2APIQuotaConfig.accounts()
        guard !accounts.isEmpty else {
            return Sub2APISnapshot(
                generatedAt: now,
                error: "未配置 Sub2API 账号，请在 Sub2API 页面添加 Base URL 和 API Key"
            )
        }

        var reports: [Sub2APIAccountReport] = []
        for account in accounts {
            do {
                let body = try fetchUsage(baseURL: account.baseURL, apiKey: account.apiKey)
                var report = try Self.parseResponse(body)
                report.id = account.id
                report.name = account.name
                reports.append(report)
            } catch {
                reports.append(Sub2APIAccountReport(
                    id: account.id,
                    name: account.name,
                    error: error.localizedDescription
                ))
            }
        }

        let allFailed = reports.allSatisfy { $0.error != nil }
        return Sub2APISnapshot(
            generatedAt: now,
            accounts: reports,
            error: allFailed ? "所有账号刷新失败：\(reports.first?.error ?? "未知错误")" : nil
        )
    }

    /// `/v1/usage` endpoint for a configured base URL. Accepts the bare origin
    /// (`https://x.y`), a trailing slash, or a base that already ends in `/v1`.
    public static func usageURL(baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.lowercased().hasSuffix("/v1") {
            base.removeLast(3)
            while base.hasSuffix("/") { base.removeLast() }
        }
        return base + "/v1/usage"
    }

    private func fetchUsage(baseURL: String, apiKey: String) throws -> String {
        let url = Self.usageURL(baseURL: baseURL)
        var configLines = [
            "silent",
            "show-error",
            QuotaProcessSupport.curlConfigLine("max-time", "30"),
            QuotaProcessSupport.curlConfigLine("url", url),
            QuotaProcessSupport.curlConfigLine("header", "Authorization: Bearer \(apiKey)"),
            QuotaProcessSupport.curlConfigLine("header", "Accept: application/json")
        ]
        if let proxy = QuotaProxyResolver.curlProxy(
            for: url,
            manualOverride: Sub2APIQuotaProxyConfig.proxyURL
        ) {
            configLines.append(QuotaProcessSupport.curlConfigLine("proxy", proxy))
        }

        let configURL = try QuotaProcessSupport.writeCurlConfig(configLines)
        defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-K", configURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let result = try QuotaProcessSupport.run(process)

        guard result.status == 0 else {
            let stderr = String(data: result.stderr, encoding: .utf8) ?? "unknown error"
            throw Sub2APIQuotaError.httpError("curl exited with status \(result.status): \(stderr)")
        }

        let output = String(data: result.stdout, encoding: .utf8) ?? ""
        if output.isEmpty {
            throw Sub2APIQuotaError.httpError("empty response from \(url)")
        }
        return output
    }

    /// Parses one `/v1/usage` body into an account report. `id`/`name` are
    /// filled by the caller from the account config.
    public static func parseResponse(_ body: String) throws -> Sub2APIAccountReport {
        guard let data = body.data(using: .utf8) else {
            throw Sub2APIQuotaError.parseError("invalid response encoding")
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw Sub2APIQuotaError.parseError("unexpected response: \(String(body.prefix(200)))")
        }

        // Every Envelope field is optional, so an error body also "decodes";
        // treat a payload-free response as the error it actually is.
        let hasPayload = envelope.isValid != nil || envelope.subscription != nil || envelope.usage != nil
            || envelope.dailyUsage != nil || envelope.modelStats != nil
        if !hasPayload {
            if let apiError = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
               let message = apiError.message {
                throw Sub2APIQuotaError.apiError(message)
            }
            throw Sub2APIQuotaError.parseError("unexpected response: \(String(body.prefix(200)))")
        }

        if envelope.isValid == false {
            throw Sub2APIQuotaError.apiError("API Key 无效或已被禁用")
        }

        var daily: Sub2APILimitWindow?
        var weekly: Sub2APILimitWindow?
        var monthly: Sub2APILimitWindow?
        if let subscription = envelope.subscription {
            if let limit = subscription.dailyLimitUSD {
                daily = Sub2APILimitWindow(limitUSD: limit, usageUSD: subscription.dailyUsageUSD ?? 0)
            }
            if let limit = subscription.weeklyLimitUSD {
                weekly = Sub2APILimitWindow(limitUSD: limit, usageUSD: subscription.weeklyUsageUSD ?? 0)
            }
            if let limit = subscription.monthlyLimitUSD {
                monthly = Sub2APILimitWindow(limitUSD: limit, usageUSD: subscription.monthlyUsageUSD ?? 0)
            }
        }

        return Sub2APIAccountReport(
            id: "",
            name: "",
            planName: envelope.planName,
            mode: envelope.mode,
            remainingUSD: envelope.remaining,
            expiresAt: envelope.subscription?.expiresAt.flatMap(Self.parseDate),
            daily: daily,
            weekly: weekly,
            monthly: monthly,
            today: envelope.usage?.today?.summary ?? Sub2APITokenSummary(),
            total: envelope.usage?.total?.summary ?? Sub2APITokenSummary(),
            days: (envelope.dailyUsage ?? [])
                .compactMap { item in
                    item.date.map { Sub2APIDayUsage(period: $0, summary: item.summary) }
                }
                .sorted { $0.period < $1.period },
            models: (envelope.modelStats ?? [])
                .compactMap { item in
                    item.model.map { Sub2APIModelStat(name: $0, summary: item.summary) }
                }
                .sorted { lhs, rhs in
                    if lhs.summary.actualCost == rhs.summary.actualCost { return lhs.name < rhs.name }
                    return lhs.summary.actualCost > rhs.summary.actualCost
                }
        )
    }

    /// `expires_at` arrives as ISO8601 with fractional seconds and a zone
    /// offset ("2027-04-30T17:09:43.320667+08:00"); tolerate both variants.
    static func parseDate(_ value: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

public enum Sub2APIQuotaError: Error, LocalizedError {
    case httpError(String)
    case apiError(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let message):
            return message
        case .apiError(let message):
            return message
        case .parseError(let message):
            return message
        }
    }
}

// MARK: - /v1/usage JSON

private struct Envelope: Decodable {
    var isValid: Bool?
    var mode: String?
    var planName: String?
    var remaining: Double?
    var subscription: Subscription?
    var dailyUsage: [TokenItem]?
    var modelStats: [TokenItem]?
    var usage: UsageBlock?

    enum CodingKeys: String, CodingKey {
        case isValid, mode, planName, remaining, subscription, usage
        case dailyUsage = "daily_usage"
        case modelStats = "model_stats"
    }
}

private struct Subscription: Decodable {
    var dailyLimitUSD: Double?
    var dailyUsageUSD: Double?
    var weeklyLimitUSD: Double?
    var weeklyUsageUSD: Double?
    var monthlyLimitUSD: Double?
    var monthlyUsageUSD: Double?
    var expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case dailyLimitUSD = "daily_limit_usd"
        case dailyUsageUSD = "daily_usage_usd"
        case weeklyLimitUSD = "weekly_limit_usd"
        case weeklyUsageUSD = "weekly_usage_usd"
        case monthlyLimitUSD = "monthly_limit_usd"
        case monthlyUsageUSD = "monthly_usage_usd"
        case expiresAt = "expires_at"
    }
}

private struct UsageBlock: Decodable {
    var today: TokenItem?
    var total: TokenItem?
}

/// Shared decoder for the three token-block shapes. Field names differ per
/// block: `daily_usage` says `cache_write_tokens` where `model_stats` and
/// `usage.today/total` say `cache_creation_tokens`; only `daily_usage` carries
/// `date` and only `model_stats` carries `model`.
private struct TokenItem: Decodable {
    var date: String?
    var model: String?
    var summary: Sub2APITokenSummary

    enum CodingKeys: String, CodingKey {
        case date, model, requests, cost
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case totalTokens = "total_tokens"
        case actualCost = "actual_cost"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        model = try container.decodeIfPresent(String.self, forKey: .model)

        let input = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        let output = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        let cacheRead = try container.decodeIfPresent(Int.self, forKey: .cacheReadTokens) ?? 0
        let cacheCreate = try container.decodeIfPresent(Int.self, forKey: .cacheCreationTokens)
            ?? container.decodeIfPresent(Int.self, forKey: .cacheWriteTokens)
            ?? 0
        summary = Sub2APITokenSummary(
            requests: try container.decodeIfPresent(Int.self, forKey: .requests) ?? 0,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheCreate,
            cacheReadTokens: cacheRead,
            totalTokens: try container.decodeIfPresent(Int.self, forKey: .totalTokens)
                ?? (input + output + cacheCreate + cacheRead),
            cost: try container.decodeIfPresent(Double.self, forKey: .cost) ?? 0,
            actualCost: try container.decodeIfPresent(Double.self, forKey: .actualCost) ?? 0
        )
    }
}

private struct ErrorEnvelope: Decodable {
    struct Detail: Decodable {
        var message: String?
    }

    var error: Detail?
    var directMessage: String?

    enum CodingKeys: String, CodingKey {
        case error
        case directMessage = "message"
    }

    var message: String? {
        error?.message ?? directMessage
    }
}
