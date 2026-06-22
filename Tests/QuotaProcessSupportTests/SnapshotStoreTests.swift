import Foundation
import QuotaProcessSupport
import Testing

private struct TestSnapshot: Codable, Equatable, Sendable {
    var generatedAt: Date
    var name: String
}

@Test func snapshotStoreRoundTripsThroughJSONFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("snapshot-store-\(UUID().uuidString)", isDirectory: true)
    let url = directory.appendingPathComponent("snapshot.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = SnapshotStore<TestSnapshot>(url: url)
    let snapshot = TestSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_782_000_000),
        name: "codex"
    )

    try store.save(snapshot)

    #expect(try store.load() == snapshot)

    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains(#""generatedAt""#))
    #expect(text.contains(#""name" : "codex""#))
}

@Test func snapshotStoreDefaultURLFallsBackToGroupContainerPath() {
    let url = SnapshotStore<TestSnapshot>.defaultURL(
        fileName: "snapshot.json",
        appGroupIdentifier: "group.test.CodeQuotaDial"
    )

    #expect(url.lastPathComponent == "snapshot.json")
    #expect(url.path.contains("group.test.CodeQuotaDial"))
}
