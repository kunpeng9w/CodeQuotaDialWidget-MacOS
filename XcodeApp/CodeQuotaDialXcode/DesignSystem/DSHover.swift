import SwiftUI

/// 悬停高亮：accent 8% 底色，120ms 过渡；受 accessibilityReduceMotion 门控。
struct DSHoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = DS.Radius.control

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(
                Color.accentColor.opacity(hovering ? 0.08 : 0),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .onHover { inside in
                if reduceMotion {
                    hovering = inside
                } else {
                    withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
                }
            }
    }
}

extension View {
    func dsHoverHighlight(cornerRadius: CGFloat = DS.Radius.control) -> some View {
        modifier(DSHoverHighlight(cornerRadius: cornerRadius))
    }
}
