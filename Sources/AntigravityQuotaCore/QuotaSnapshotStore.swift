import Foundation
import QuotaProcessSupport

public struct AntigravityQuotaSnapshotStore: Sendable {
    public static let fileName = "antigravity_quota_snapshot.json"
    public static let appGroupIdentifier = AntigravityQuotaAppGroup.identifier

    private var store: SnapshotStore<AntigravityQuotaSnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = AntigravityQuotaSnapshotStore.defaultURL()) {
        store = SnapshotStore(url: url)
    }

    public static func defaultURL() -> URL {
        SnapshotStore<AntigravityQuotaSnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> AntigravityQuotaSnapshot {
        try store.load()
    }

    public func save(_ snapshot: AntigravityQuotaSnapshot) throws {
        try store.save(snapshot)
    }
}
