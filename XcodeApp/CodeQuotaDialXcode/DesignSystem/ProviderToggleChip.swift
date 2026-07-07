import SwiftUI

/// cc-switch 风格的服务开关芯片：点亮 = accent 填充胶囊（显示在总览/侧栏并
/// 开启后台刷新），熄灭 = 灰描边（隐藏并停止后台刷新）。
struct ProviderToggleChip: View {
    let section: DashboardSection
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let asset = section.iconAsset {
                    Image(asset)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .opacity(isOn ? 1 : 0.55)
                } else {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 16, height: 16)
                }
                Text(section.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, 6)
            .foregroundStyle(isOn ? Color.white : Color.secondary)
            .background(isOn ? Color.accentColor : Color.clear, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isOn ? Color.clear : Color.secondary.opacity(0.35),
                    lineWidth: 1
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isOn
              ? "点击隐藏 \(section.title)（同时停止其后台自动刷新）"
              : "点击显示 \(section.title)（同时开启其后台自动刷新）")
        .animation(.snappy, value: isOn)
    }
}
