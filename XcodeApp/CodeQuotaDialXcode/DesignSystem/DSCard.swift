import SwiftUI

/// 统一卡片表面 v2：不透明底色 + 细描边 + 微阴影（Xcode Organizer 质感），
/// 取代材质叠材质的 `cardSurface()`。
struct DSCardModifier: ViewModifier {
    var elevation: DS.Elevation = .raised
    var padded = true
    var tint: Color = .accentColor

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .padding(padded ? DS.Space.m : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if elevation != .flat {
                    shape
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                }
            }
            .overlay(shape.strokeBorder(.quaternary, lineWidth: 1))
            .overlay(alignment: .top) {
                if elevation == .prominent {
                    Capsule()
                        .fill(tint.opacity(0.8))
                        .frame(height: 2)
                        .padding(.horizontal, DS.Radius.card)
                }
            }
    }
}

extension View {
    func dsCard(
        _ elevation: DS.Elevation = .raised,
        padded: Bool = true,
        tint: Color = .accentColor
    ) -> some View {
        modifier(DSCardModifier(elevation: elevation, padded: padded, tint: tint))
    }

    /// 只换卡片表面、不注入 padding / maxWidth 的版本，
    /// 供自带固定几何的旧卡片（如消耗统计的日历热力图）换皮。
    func dsCardSurfaceOnly() -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        return background {
            shape
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .overlay(shape.strokeBorder(.quaternary, lineWidth: 1))
    }
}
