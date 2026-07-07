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
    /// 在总览/侧栏中隐藏的额度监控服务（DashboardSection rawValue）。
    /// 存「禁用」而非「启用」，缺省空数组 = 全部显示。
    var disabledProviders: [String]

    static let empty = RuntimeConfig(
        proxyURL: "",
        remoteHosts: [],
        glmApiKey: "",
        zcodeUsageEnabled: true,
        sub2apiAccounts: [],
        disabledProviders: []
    )
}

extension Notification.Name {
    /// app 内任一面板保存运行时配置后广播；导航与总览据此刷新 provider 开关。
    static let runtimeConfigDidChange = Notification.Name("RuntimeConfigDidChange")
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
        let disabledProviders = ((object["disabledProviders"] as? [String]) ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return RuntimeConfig(
            proxyURL: proxy,
            remoteHosts: hosts,
            glmApiKey: glmApiKey,
            zcodeUsageEnabled: zcodeUsageEnabled,
            sub2apiAccounts: sub2apiAccounts,
            disabledProviders: disabledProviders
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
            "disabledProviders": config.disabledProviders
        ]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        NotificationCenter.default.post(name: .runtimeConfigDidChange, object: nil)
    }
}
