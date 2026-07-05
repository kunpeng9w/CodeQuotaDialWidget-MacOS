import Foundation
import Sub2APIQuotaCore
import WidgetKit

let arguments = Array(CommandLine.arguments.dropFirst())
let outputIndex = arguments.firstIndex(of: "--output")

let outputURL: URL
if let outputIndex, arguments.indices.contains(outputIndex + 1) {
    outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
} else {
    outputURL = Sub2APIQuotaSnapshotStore.defaultURL()
}

let snapshot = Sub2APIQuotaCollector().collect()
let store = Sub2APIQuotaSnapshotStore(url: outputURL)

do {
    if snapshot.isRefreshFailure, let previous = try? store.load() {
        let reason = snapshot.error ?? "no account data"
        fputs("Quota refresh failed; keeping previous snapshot from \(previous.generatedAt): \(reason)\n", stderr)
        WidgetCenter.shared.reloadAllTimelines()
        print(outputURL.path)
        exit(0)
    }

    try store.save(snapshot)
    WidgetCenter.shared.reloadAllTimelines()
    print(outputURL.path)
} catch {
    fputs("Failed to save quota snapshot: \(error.localizedDescription)\n", stderr)
    exit(1)
}
