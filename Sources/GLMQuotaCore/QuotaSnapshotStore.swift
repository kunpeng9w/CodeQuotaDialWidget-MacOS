import Foundation

public struct GLMQuotaSnapshotStore: Sendable {
    public static let fileName = "glm_quota_snapshot.json"
    public static let appGroupIdentifier = GLMQuotaAppGroup.identifier

    public var url: URL

    public init(url: URL = GLMQuotaSnapshotStore.defaultURL()) {
        self.url = url
    }

    public static func defaultURL() -> URL {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return appGroupURL.appendingPathComponent(fileName)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers", isDirectory: true)
            .appendingPathComponent(appGroupIdentifier, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public func load() throws -> GLMQuotaSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GLMQuotaSnapshot.self, from: data)
    }

    public func save(_ snapshot: GLMQuotaSnapshot) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
