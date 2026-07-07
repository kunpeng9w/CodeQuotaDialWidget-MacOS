import SwiftUI

/// 空态占位：图标 + 标题 + 说明 + 可选动作。
/// 总览未配置卡、模型价格空态、Sub2API 无账号等场景使用。
struct DSEmptyState: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
