import Foundation

/// Reads and writes the runtime-editable settings shared with the snapshot
/// tools and the in-process collectors (proxy URL + remote SSH hosts).
///
/// The file lives at a fixed path outside any app-group container because both
/// this (unsandboxed) app and the (unsandboxed) snapshot tools need it, and the
/// tools belong to five different app groups. Editing it here takes effect on
/// the next refresh — the cores re-read the file on every collect — so the proxy
/// and remote hosts no longer require a rebuild/reinstall to change.
struct RuntimeConfig: Equatable {
    var proxyURL: String
    var remoteHosts: [String]
    var glmApiKey: String
    var zcodeUsageEnabled: Bool
    var sub2apiAccounts: [Sub2APIAccountEntry]
    var sub2apiUsageEnabled: Bool

    static let empty = RuntimeConfig(
        proxyURL: "",
        remoteHosts: [],
        glmApiKey: "",
        zcodeUsageEnabled: true,
        sub2apiAccounts: [],
        sub2apiUsageEnabled: true
    )
}

/// One sub2api relay account (name + base URL + key), stored plaintext in the
/// 0600 runtime config like the GLM key.
struct Sub2APIAccountEntry: Equatable, Identifiable {
    var id: String
    var name: String
    var baseURL: String
    var apiKey: String

    static func makeID() -> String { UUID().uuidString }
}

enum RuntimeConfigStore {
    static let url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodeQuotaDial", isDirectory: true)
        .appendingPathComponent("runtime-config.json")

    static func load() -> RuntimeConfig {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .empty }

        let proxy = (object["proxyURL"] as? String) ?? ""
        let hosts = (object["remoteHosts"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []
        let glmApiKey = ((object["glmApiKey"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
        let zcodeUsageEnabled = (object["zcodeUsageEnabled"] as? Bool) ?? true
        let sub2apiAccounts = ((object["sub2apiAccounts"] as? [[String: Any]]) ?? []).compactMap { entry -> Sub2APIAccountEntry? in
            let baseURL = ((entry["baseURL"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = ((entry["apiKey"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !baseURL.isEmpty, !apiKey.isEmpty else { return nil }
            let id = ((entry["id"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
            return Sub2APIAccountEntry(
                id: id.isEmpty ? Sub2APIAccountEntry.makeID() : id,
                name: ((entry["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: baseURL,
                apiKey: apiKey
            )
        }
        let sub2apiUsageEnabled = (object["sub2apiUsageEnabled"] as? Bool) ?? true
        return RuntimeConfig(
            proxyURL: proxy,
            remoteHosts: hosts,
            glmApiKey: glmApiKey,
            zcodeUsageEnabled: zcodeUsageEnabled,
            sub2apiAccounts: sub2apiAccounts,
            sub2apiUsageEnabled: sub2apiUsageEnabled
        )
    }

    static func save(_ config: RuntimeConfig) throws {
        let object: [String: Any] = [
            "proxyURL": config.proxyURL.trimmingCharacters(in: .whitespaces),
            "remoteHosts": config.remoteHosts
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty },
            "glmApiKey": config.glmApiKey.trimmingCharacters(in: .whitespaces),
            "zcodeUsageEnabled": config.zcodeUsageEnabled,
            "sub2apiAccounts": config.sub2apiAccounts.map { account in
                [
                    "id": account.id,
                    "name": account.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "baseURL": account.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    "apiKey": account.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
            },
            "sub2apiUsageEnabled": config.sub2apiUsageEnabled
        ]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
