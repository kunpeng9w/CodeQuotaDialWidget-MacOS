import Foundation
import Testing

@testable import UsagePanelSupport

@Test func periodicReloadKeepsRefreshErrorForSameSnapshot() {
    let generatedAt = Date(timeIntervalSince1970: 100)

    let error = SnapshotReloadErrorLogic.resolvedErrorText(
        currentError: "刷新失败，保留旧数据",
        reloadedError: nil,
        previousGeneratedAt: generatedAt,
        reloadedGeneratedAt: generatedAt,
        preserveCurrentWhenUnchanged: true
    )

    #expect(error == "刷新失败，保留旧数据")
}

@Test func newerSnapshotReplacesRefreshError() {
    let error = SnapshotReloadErrorLogic.resolvedErrorText(
        currentError: "刷新失败，保留旧数据",
        reloadedError: nil,
        previousGeneratedAt: Date(timeIntervalSince1970: 100),
        reloadedGeneratedAt: Date(timeIntervalSince1970: 200),
        preserveCurrentWhenUnchanged: true
    )

    #expect(error == nil)
}

@Test func initialLoadUsesSnapshotError() {
    let error = SnapshotReloadErrorLogic.resolvedErrorText(
        currentError: "旧错误",
        reloadedError: "快照错误",
        previousGeneratedAt: nil,
        reloadedGeneratedAt: nil,
        preserveCurrentWhenUnchanged: false
    )

    #expect(error == "快照错误")
}
