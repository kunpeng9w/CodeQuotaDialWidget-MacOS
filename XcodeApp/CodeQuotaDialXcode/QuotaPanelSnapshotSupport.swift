import AntigravityQuotaCore
import ClaudeQuotaCore
import CodexQuotaCore
import Foundation
import GLMQuotaCore
import WidgetKit

protocol QuotaPanelRefreshSnapshot: Sendable {
    var generatedAt: Date { get }
    var error: String? { get }
    var isRefreshFailure: Bool { get }
}

protocol QuotaPanelSnapshotStoring: Sendable {
    associatedtype Snapshot: QuotaPanelRefreshSnapshot

    func load() throws -> Snapshot
    func save(_ snapshot: Snapshot) throws
}

struct QuotaPanelSnapshotState<Snapshot> {
    var snapshot: Snapshot?
    var errorText: String?
}

func loadQuotaPanelSnapshot<Store: QuotaPanelSnapshotStoring>(
    from store: Store,
    emptyMessage: String = "暂无额度快照，请先刷新。"
) -> QuotaPanelSnapshotState<Store.Snapshot> {
    do {
        let snapshot = try store.load()
        return QuotaPanelSnapshotState(snapshot: snapshot, errorText: snapshot.error)
    } catch {
        return QuotaPanelSnapshotState(snapshot: nil, errorText: emptyMessage)
    }
}

func refreshQuotaPanelSnapshot<Store: QuotaPanelSnapshotStoring>(
    store: Store,
    currentSnapshot: Store.Snapshot?,
    fallbackReason: String,
    collect: @escaping @Sendable () -> Store.Snapshot
) async -> QuotaPanelSnapshotState<Store.Snapshot> {
    let newSnapshot = await Task.detached(operation: collect).value

    do {
        if newSnapshot.isRefreshFailure, let previous = currentSnapshot ?? (try? store.load()) {
            let reason = newSnapshot.error ?? fallbackReason
            return QuotaPanelSnapshotState(
                snapshot: previous,
                errorText: "刷新失败，保留 \(quotaPanelTimeFormatter.string(from: previous.generatedAt)) 的数据：\(reason)"
            )
        }

        try store.save(newSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return QuotaPanelSnapshotState(snapshot: newSnapshot, errorText: newSnapshot.error)
    } catch {
        return QuotaPanelSnapshotState(
            snapshot: currentSnapshot,
            errorText: "保存额度快照失败：\(error.localizedDescription)"
        )
    }
}

let quotaPanelTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
}()

extension CodexQuotaSnapshot: QuotaPanelRefreshSnapshot {}
extension ClaudeQuotaSnapshot: QuotaPanelRefreshSnapshot {}
extension GLMQuotaSnapshot: QuotaPanelRefreshSnapshot {}
extension AntigravityQuotaSnapshot: QuotaPanelRefreshSnapshot {}

extension CodexQuotaSnapshotStore: QuotaPanelSnapshotStoring {}
extension ClaudeQuotaSnapshotStore: QuotaPanelSnapshotStoring {}
extension GLMQuotaSnapshotStore: QuotaPanelSnapshotStoring {}
extension AntigravityQuotaSnapshotStore: QuotaPanelSnapshotStoring {}
