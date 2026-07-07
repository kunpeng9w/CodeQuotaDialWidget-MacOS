import SwiftUI

/// 区块小标题：统一取代各面板手写的 caption-semibold 标题行，
/// 可选副标题与尾随控件（按钮 / Picker / chip）。
struct DSSectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Text(title)
                .font(DS.Typo.cardLabel)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(DS.Typo.meta)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension DSSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}
