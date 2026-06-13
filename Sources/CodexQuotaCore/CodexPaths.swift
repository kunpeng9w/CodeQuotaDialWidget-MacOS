import Foundation

public struct CodexPaths: Sendable {
    public var codexBinaryPath: String

    public init(codexBinaryPath: String = CodexPaths.defaultCodexBinaryPath()) {
        self.codexBinaryPath = codexBinaryPath
    }

    public static func defaultCodexBinaryPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".codex/packages/standalone/current/bin/codex").path,
            home.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "codex"
    }
}
