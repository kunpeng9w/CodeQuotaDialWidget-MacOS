import Foundation
import QuotaProcessSupport

public struct CodexQuotaSnapshotStore: Sendable {
    public static let fileName = "codex_quota_snapshot.json"
    public static let appGroupIdentifier = CodexQuotaAppGroup.identifier

    private var store: SnapshotStore<CodexQuotaSnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = CodexQuotaSnapshotStore.defaultURL()) {
        store = SnapshotStore(url: url)
    }

    public static func defaultURL() -> URL {
        SnapshotStore<CodexQuotaSnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> CodexQuotaSnapshot {
        try store.load()
    }

    public func save(_ snapshot: CodexQuotaSnapshot) throws {
        try store.save(snapshot)
    }
}
