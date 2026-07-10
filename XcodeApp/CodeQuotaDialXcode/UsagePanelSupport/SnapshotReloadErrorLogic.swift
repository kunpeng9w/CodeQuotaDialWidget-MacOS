import Foundation

/// Merges snapshot errors during periodic file reloads without erasing a
/// transient manual-refresh/save error for the same snapshot generation.
enum SnapshotReloadErrorLogic {
    static func resolvedErrorText(
        currentError: String?,
        reloadedError: String?,
        previousGeneratedAt: Date?,
        reloadedGeneratedAt: Date?,
        preserveCurrentWhenUnchanged: Bool
    ) -> String? {
        if preserveCurrentWhenUnchanged,
           currentError != nil,
           previousGeneratedAt == reloadedGeneratedAt {
            return currentError
        }
        return reloadedError
    }
}
