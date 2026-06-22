import Foundation
import QuotaProcessSupport

public struct UsageSnapshotStore: Sendable {
    public static let fileName = "usage_quota_snapshot.json"
    public static let appGroupIdentifier = UsageQuotaAppGroup.identifier

    private var store: SnapshotStore<UsageSnapshot>

    public var url: URL {
        get { store.url }
        set { store.url = newValue }
    }

    public init(url: URL = UsageSnapshotStore.defaultURL()) {
        store = SnapshotStore(
            url: url,
            makeDecoder: Self.makeDecoder,
            makeEncoder: Self.makeEncoder
        )
    }

    public static func defaultURL() -> URL {
        SnapshotStore<UsageSnapshot>.defaultURL(
            fileName: fileName,
            appGroupIdentifier: appGroupIdentifier
        )
    }

    public func load() throws -> UsageSnapshot {
        try store.load()
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        try store.save(snapshot)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601Date(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
