import Foundation

public struct GLMConfig: Sendable {
    public var apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public static func load() throws -> GLMConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".glm_quota_config.json")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw GLMConfigError.fileNotFound(configPath.path)
        }

        let data = try Data(contentsOf: configPath)
        let decoded = try JSONDecoder().decode(ConfigFile.self, from: data)

        let apiKey = decoded.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw GLMConfigError.emptyKey
        }

        return GLMConfig(apiKey: apiKey)
    }
}

private struct ConfigFile: Decodable {
    var apiKey: String
}

public enum GLMConfigError: Error, LocalizedError {
    case fileNotFound(String)
    case emptyKey

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "配置文件不存在: \(path)，请创建并填入 {\"apiKey\": \"YOUR_KEY\"}"
        case .emptyKey:
            return "apiKey 为空，请在 ~/.glm_quota_config.json 中填入有效的 API Key"
        }
    }
}
