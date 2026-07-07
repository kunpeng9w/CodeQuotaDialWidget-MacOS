import QuotaProcessSupport
import SwiftUI

/// In-app editor for the runtime settings that used to require a reinstall:
/// the network proxy (shared by Codex/Claude/GLM) and the remote SSH hosts for
/// the Usage widget's multi-end aggregation. Saving writes the shared config
/// file; every collector re-reads it on the next refresh.
struct SettingsPanelView: View {
    @State private var proxyURL = ""
    @State private var remoteHostsText = ""
    @State private var zcodeUsageEnabled = true
    @State private var savedConfig = RuntimeConfig.empty
    @State private var statusText: String?
    @State private var isError = false
    @State private var disabledProviders: Set<String> = []
    @State private var systemProxyText: String?

    var body: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.xs) {
                        ForEach(DashboardSection.quotaCases) { section in
                            ProviderToggleChip(
                                section: section,
                                isOn: !disabledProviders.contains(section.rawValue),
                                action: { toggleProvider(section) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Label("主页面显示", systemImage: "square.grid.2x2")
            } footer: {
                Text("选择在总览与侧栏中显示的额度监控服务。熄灭后隐藏该服务并停止其后台自动刷新；点亮恢复显示并重新开启。即时生效，无需保存。")
            }

            Section {
                TextField(
                    "代理地址",
                    text: $proxyURL,
                    prompt: Text(systemProxyText ?? "当前系统代理探测中…")
                )
                .font(.system(.body, design: .monospaced))
            } header: {
                Label("网络代理", systemImage: "network")
            } footer: {
                Text("供 Codex / Claude / GLM 拉取额度时使用。留空=自动跟随 macOS 系统代理；填写=覆盖系统代理。")
            }

            Section {
                TextEditor(text: $remoteHostsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 72)
            } header: {
                Label("远端 SSH 主机", systemImage: "server.rack")
            } footer: {
                Text("供“消耗”统计做多端汇总，每行一个 host（需已配置免密登录且远端有 ccusage）。留空=仅本机。")
            }

            Section {
                Toggle(isOn: $zcodeUsageEnabled) {
                    Label("ZCode 用量扩展", systemImage: "bolt.horizontal.circle")
                }
            } footer: {
                Text("开启后读取本机 ~/.zcode/cli/db/db.sqlite，并作为 ZCode Agent 合并到“消耗”统计。")
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .navigationTitle("设置")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(isError ? .orange : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button("还原") { load() }
                    .disabled(!isDirty)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isDirty)
            }
        }
        .onAppear {
            load()
            probeSystemProxy()
        }
    }

    /// 实时解析当前系统代理（含 PAC，可能有网络等待），结果作为输入框占位符。
    private func probeSystemProxy() {
        Task.detached(priority: .utility) {
            let proxy = QuotaProxyResolver.curlProxy(for: "https://api.openai.com", manualOverride: nil)
            let text = "当前系统代理：\(proxy ?? "直连")"
            await MainActor.run { systemProxyText = text }
        }
    }

    private var editedConfig: RuntimeConfig {
        // glmApiKey / sub2api accounts / provider 开关由各自的控件即时持久化；
        // carry the saved values through untouched so saving here never wipes them.
        RuntimeConfig(
            proxyURL: proxyURL.trimmingCharacters(in: .whitespaces),
            remoteHosts: parseHosts(remoteHostsText),
            glmApiKey: savedConfig.glmApiKey,
            zcodeUsageEnabled: zcodeUsageEnabled,
            sub2apiAccounts: savedConfig.sub2apiAccounts,
            disabledProviders: savedConfig.disabledProviders
        )
    }

    private var isDirty: Bool { editedConfig != savedConfig }

    private func load() {
        let config = RuntimeConfigStore.load()
        savedConfig = config
        proxyURL = config.proxyURL
        remoteHostsText = config.remoteHosts.joined(separator: "\n")
        zcodeUsageEnabled = config.zcodeUsageEnabled
        disabledProviders = Set(config.disabledProviders)
        statusText = nil
        isError = false
    }

    /// provider 显示开关：即时持久化（独立于保存/还原的表单流），
    /// 并联动开/关该服务的后台刷新代理。
    private func toggleProvider(_ section: DashboardSection) {
        let turningOff = !disabledProviders.contains(section.rawValue)
        var disabled = disabledProviders
        if turningOff {
            disabled.insert(section.rawValue)
        } else {
            disabled.remove(section.rawValue)
        }

        // 以磁盘为准读写，保住其他面板的即时修改；表单里未保存的编辑不受影响。
        var config = RuntimeConfigStore.load()
        config.disabledProviders = disabled.sorted()
        do {
            try RuntimeConfigStore.save(config)
            disabledProviders = disabled
            savedConfig.disabledProviders = disabled.sorted()
            statusText = nil
            isError = false
        } catch {
            statusText = "保存失败：\(error.localizedDescription)"
            isError = true
            return
        }

        guard let spec = agentSpec(for: section) else { return }
        Task {
            do {
                try await LaunchAgentController.setAgentRunning(
                    !turningOff,
                    label: spec.label,
                    plistPath: spec.plist
                )
            } catch {
                statusText = error.localizedDescription
                isError = true
            }
        }
    }

    private func agentSpec(for section: DashboardSection) -> (label: String, plist: String)? {
        switch section {
        case .codex: return LaunchAgentLabels.codex
        case .claude: return LaunchAgentLabels.claude
        case .glm: return LaunchAgentLabels.glm
        case .antigravity: return LaunchAgentLabels.antigravity
        case .sub2api: return LaunchAgentLabels.sub2api
        case .overview, .usage, .modelPrices, .settings: return nil
        }
    }

    private func save() {
        let config = editedConfig
        do {
            try RuntimeConfigStore.save(config)
            savedConfig = config
            // Reflect the normalized values back (trimmed proxy, cleaned hosts).
            proxyURL = config.proxyURL
            remoteHostsText = config.remoteHosts.joined(separator: "\n")
            zcodeUsageEnabled = config.zcodeUsageEnabled
            statusText = "已保存"
            isError = false
        } catch {
            statusText = "保存失败：\(error.localizedDescription)"
            isError = true
        }
    }

    private func parseHosts(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
