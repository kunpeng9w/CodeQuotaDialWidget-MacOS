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

    var body: some View {
        Form {
            Section {
                TextField("http://127.0.0.1:7897", text: $proxyURL)
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
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle("设置")
        .onAppear(perform: load)
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isDirty)
                Button("还原") { load() }
                    .disabled(!isDirty)
                Spacer(minLength: 0)
                if let statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(isError ? .orange : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            FootnoteRow(text: "保存后在对应面板点“刷新”，或等待后台自动刷新即可生效，无需重新安装。")
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.s)
        .background(.bar)
    }

    private var editedConfig: RuntimeConfig {
        // glmApiKey and the sub2api accounts are owned by their panels; carry
        // the saved values through untouched so saving here never wipes them.
        RuntimeConfig(
            proxyURL: proxyURL.trimmingCharacters(in: .whitespaces),
            remoteHosts: parseHosts(remoteHostsText),
            glmApiKey: savedConfig.glmApiKey,
            zcodeUsageEnabled: zcodeUsageEnabled,
            sub2apiAccounts: savedConfig.sub2apiAccounts
        )
    }

    private var isDirty: Bool { editedConfig != savedConfig }

    private func load() {
        let config = RuntimeConfigStore.load()
        savedConfig = config
        proxyURL = config.proxyURL
        remoteHostsText = config.remoteHosts.joined(separator: "\n")
        zcodeUsageEnabled = config.zcodeUsageEnabled
        statusText = nil
        isError = false
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
