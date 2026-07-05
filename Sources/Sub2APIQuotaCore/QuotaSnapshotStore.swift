import Foundation
import QuotaProcessSupport

public struct Sub2APIQuotaSnapshotStore: Sendable {
    public static let fileName = "sub2api_quota_snapshot.json"
    public static let appGroupIdentifier = Sub2APIQuotaAppGroup.identifier

    private var store: SnapshotStore<Sub2APISnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = Sub2APIQuotaSnapshotStore.defaultURL()) {
        store = SnapshotStore(url: url)
    }

    public static func defaultURL() -> URL {
        SnapshotStore<Sub2APISnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> Sub2APISnapshot {
        try store.load()
    }

    public func save(_ snapshot: Sub2APISnapshot) throws {
        try store.save(snapshot)
    }
}
