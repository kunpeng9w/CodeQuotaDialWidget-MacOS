import Foundation
import QuotaProcessSupport

public struct GLMQuotaSnapshotStore: Sendable {
    public static let fileName = "glm_quota_snapshot.json"
    public static let appGroupIdentifier = GLMQuotaAppGroup.identifier

    private var store: SnapshotStore<GLMQuotaSnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = GLMQuotaSnapshotStore.defaultURL()) {
        store = SnapshotStore(url: url)
    }

    public static func defaultURL() -> URL {
        SnapshotStore<GLMQuotaSnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> GLMQuotaSnapshot {
        try store.load()
    }

    public func save(_ snapshot: GLMQuotaSnapshot) throws {
        try store.save(snapshot)
    }
}
