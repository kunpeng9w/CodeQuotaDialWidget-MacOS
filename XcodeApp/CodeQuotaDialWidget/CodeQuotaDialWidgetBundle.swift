import CodexQuotaDialWidget
import AntigravityQuotaDialWidget
import ClaudeQuotaDialWidget
import GLMQuotaDialWidget
import Sub2APIQuotaDialWidget
import UsageQuotaDialWidget
import SwiftUI
import WidgetKit

@main
struct CodeQuotaDialWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexQuotaDialWidget()
        ClaudeQuotaDialWidget()
        GLMQuotaDialWidget()
        AntigravityQuotaDialWidget()
        Sub2APIQuotaDialWidget()
        UsageQuotaDialWidget()
    }
}
