import SwiftUI

struct PanelBadge: Identifiable {
    var text: String
    var tint: Color = .blue
    var muted = false

    var id: String { text }
}

/// 统一面板骨架：头部（provider 图标 · 标题 · 徽标 · 后台刷新状态）+
/// 错误横幅 + 内容列。只负责摆放；数据加载、刷新、toolbar、
/// navigationTitle 仍由各面板自持。
struct PanelScaffold<Content: View>: View {
    let section: DashboardSection
    var updatedAt: Date?
    var badges: [PanelBadge] = []
    var statusLine: String?
    var agent: LaunchAgentController?
    var errorText: String?
    /// 头部尾随的附加控件（如范围 Picker），排在后台开关之前。
    var headerAccessory: AnyView?
    var maxContentWidth: CGFloat = 1024
    /// 自带内部滚动的面板（如模型价格的表格）关掉外层 ScrollView，
    /// 让内容用满剩余高度。
    var scrollable = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        if scrollable {
            ScrollView { inner }
        } else {
            inner
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            header

            if let errorText {
                InlineBanner(text: errorText)
            }

            content()
        }
        .padding(DS.Space.xl)
        // 封顶内容列宽，超宽窗口的余量变成对称边距（原消耗统计逻辑上移至此）。
        .frame(maxWidth: maxContentWidth, alignment: .topLeading)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.s) {
            PanelSectionIcon(section: section)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Space.xs) {
                    Text(section.title)
                        .font(DS.Typo.panelTitle)
                    ForEach(badges) { badge in
                        TagBadge(text: badge.text, tint: badge.tint, muted: badge.muted)
                    }
                }

                if let metaLine {
                    Text(metaLine)
                        .font(DS.Typo.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: DS.Space.s)

            if let headerAccessory {
                headerAccessory
            }

            if let agent {
                CompactAgentToggle(controller: agent)
            }
        }
        .padding(.bottom, DS.Space.xs)
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let statusLine { parts.append(statusLine) }
        if let updatedAt { parts.append("更新于 \(quotaPanelTimeFormatter.string(from: updatedAt))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 面板头部的 provider 图标（28pt 版，与侧栏 SectionIcon 同源不同尺寸）。
private struct PanelSectionIcon: View {
    let section: DashboardSection

    var body: some View {
        if let asset = section.iconAsset {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: section.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(section.accent)
                .frame(width: 28, height: 28)
        }
    }
}

/// 头部紧凑版后台刷新开关：与 LaunchAgentToggleRow 相同的
/// controller / Binding / 禁用逻辑，只换摆位。
struct CompactAgentToggle: View {
    @ObservedObject var controller: LaunchAgentController

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            Toggle(isOn: Binding(
                get: { controller.isRunning },
                set: { controller.setRunning($0) }
            )) {
                Text("后台自动刷新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(
                controller.status == .notInstalled
                    || controller.status == .checking
                    || controller.isToggling
            )

            StatusDot(status: controller.status)
        }
        .help(controller.status == .notInstalled
              ? "未安装后台刷新，请在仓库内运行 script/install.command"
              : "")
    }
}
