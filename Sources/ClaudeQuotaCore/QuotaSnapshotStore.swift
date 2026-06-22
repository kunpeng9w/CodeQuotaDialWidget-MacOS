import Foundation
import QuotaProcessSupport

public struct ClaudeQuotaSnapshotStore: Sendable {
    public static let fileName = "claude_quota_snapshot.json"
    public static let appGroupIdentifier = ClaudeQuotaAppGroup.identifier

    private var store: SnapshotStore<ClaudeQuotaSnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = ClaudeQuotaSnapshotStore.defaultURL()) {
        store = SnapshotStore(url: url)
    }

    public static func defaultURL() -> URL {
        SnapshotStore<ClaudeQuotaSnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> ClaudeQuotaSnapshot {
        try store.load()
    }

    public func save(_ snapshot: ClaudeQuotaSnapshot) throws {
        try store.save(snapshot)
    }
}
