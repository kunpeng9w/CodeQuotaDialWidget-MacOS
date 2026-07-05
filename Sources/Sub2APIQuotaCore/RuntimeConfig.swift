import Foundation

/// Runtime-editable settings shared by the GUI app and the snapshot tools.
/// See ClaudeQuotaCore/RuntimeConfig.swift for the rationale; the file is the
/// same one across every widget so a single in-app edit covers them all.
enum QuotaRuntimeConfigFile {
    /// `~/Library/Application Support/CodeQuotaDial/runtime-config.json`.
    static let url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodeQuotaDial", isDirectory: true)
        .appendingPathComponent("runtime-config.json")

    static func object() -> [String: Any] {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object
    }
}

public enum Sub2APIQuotaProxyConfig {
    /// Manual proxy override passed to curl via `--proxy`. `nil`/empty means
    /// the collector falls back to the current macOS system proxy.
    public static var proxyURL: String? {
        guard let value = QuotaRuntimeConfigFile.object()["proxyURL"] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}

/// One relay account: a base URL plus its API key, with a user-chosen display
/// name. Stored (plaintext, 0600) in the shared runtime config like the GLM
/// key — local dev signing cannot authorize Keychain sharing across the tools.
public struct Sub2APIAccountConfig: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var baseURL: String
    public var apiKey: String

    public init(id: String, name: String, baseURL: String, apiKey: String) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

public enum Sub2APIQuotaConfig {
    /// Accounts configured in the Sub2API panel (`sub2apiAccounts` in the
    /// shared runtime config). Entries without a base URL or key are skipped.
    public static func accounts() -> [Sub2APIAccountConfig] {
        guard let raw = QuotaRuntimeConfigFile.object()["sub2apiAccounts"] as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { entry in
            let baseURL = ((entry["baseURL"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = ((entry["apiKey"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !baseURL.isEmpty, !apiKey.isEmpty else { return nil }
            let name = ((entry["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let id = ((entry["id"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
            return Sub2APIAccountConfig(
                id: id.isEmpty ? baseURL + "#" + String(apiKey.suffix(8)) : id,
                name: name.isEmpty ? Self.fallbackName(for: baseURL) : name,
                baseURL: baseURL,
                apiKey: apiKey
            )
        }
    }

    static func fallbackName(for baseURL: String) -> String {
        URL(string: baseURL)?.host ?? baseURL
    }
}
