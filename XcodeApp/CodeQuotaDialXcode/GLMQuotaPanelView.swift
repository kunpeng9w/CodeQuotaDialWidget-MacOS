import GLMQuotaCore
import SwiftUI
import WidgetKit

struct GLMQuotaPanelView: View {
    @State private var snapshot: GLMQuotaSnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @State private var keyIsSet = false
    @State private var isEditingKey = false
    @State private var apiKeyInput = ""
    @State private var keyStatus: String?
    @State private var showKeyPopover = false
    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.glm.label,
        plistPath: LaunchAgentLabels.glm.plist
    )

    var body: some View {
        PanelScaffold(
            section: .glm,
            updatedAt: snapshot?.generatedAt,
            badges: snapshot?.level.map { [PanelBadge(text: $0.uppercased(), tint: .blue)] } ?? [],
            agent: agent,
            errorText: errorText ?? agent.lastError,
            headerAccessory: AnyView(apiKeyControl)
        ) {
            HStack(spacing: DS.Space.s) {
                gaugeCard(title: "工具类额度", window: snapshot?.timeLimit)
                gaugeCard(title: "5h", window: snapshot?.tokensLimit5)
                gaugeCard(title: "本周", window: snapshot?.tokensLimitWeek)
            }

            AgentUsageTrendCard(agentName: "zcode", displayName: "ZCode Agent", tint: .blue)

            FootnoteRow(text: "桌面组件每 2 分钟读取快照")
        }
        .navigationTitle("GLM 额度")
        .navigationSubtitle(snapshot.map { "更新于 \(quotaPanelTimeFormatter.string(from: $0.generatedAt))" } ?? "未刷新")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshButton(isRefreshing: isRefreshing) { await refresh() }
            }
        }
        .onAppear {
            loadSnapshot()
            agent.refreshStatus()
            keyIsSet = GLMConfig.resolvedApiKey() != nil
        }
    }

    // MARK: - 表盘卡

    private func gaugeCard(title: String, window: GLMQuotaWindow?) -> some View {
        let model = QuotaStatModel(window)
        return QuotaGaugeCard(
            title: title,
            model: model,
            detailLines: model.absoluteText.map { [$0] } ?? []
        )
    }

    // MARK: - API Key（头部紧凑控件 + popover 编辑器）

    private var apiKeyControl: some View {
        HStack(spacing: DS.Space.xs) {
            if keyIsSet && !isEditingKey {
                TagBadge(text: "Key 已设置", tint: .green)
                Button("修改") {
                    apiKeyInput = ""
                    isEditingKey = true
                    keyStatus = nil
                    showKeyPopover = true
                }
                .controlSize(.small)
            } else {
                Button("设置 API Key") {
                    apiKeyInput = ""
                    isEditingKey = true
                    keyStatus = nil
                    showKeyPopover = true
                }
                .controlSize(.small)
            }
        }
        .popover(isPresented: $showKeyPopover, arrowEdge: .bottom) {
            apiKeyEditor
        }
    }

    private var apiKeyEditor: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("GLM API Key")
                .font(DS.Typo.cardLabel)
                .foregroundStyle(.secondary)
            // Editing / unset state: visible while typing so it can be verified.
            TextField("粘贴 GLM API Key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 280)
            HStack(spacing: 8) {
                Button("保存") {
                    saveApiKey()
                    // saveApiKey 成功时会退出编辑态（isEditingKey = false）。
                    if !isEditingKey { showKeyPopover = false }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("取消") {
                    apiKeyInput = ""
                    isEditingKey = false
                    keyStatus = nil
                    showKeyPopover = false
                }
                .controlSize(.small)
                Spacer()
                if let keyStatus {
                    Text(keyStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Space.s)
    }

    private func saveApiKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        var config = RuntimeConfigStore.load()   // preserve proxy / remote hosts
        config.glmApiKey = key
        do {
            try RuntimeConfigStore.save(config)
            apiKeyInput = ""        // drop the plaintext from memory / view
            keyIsSet = true
            isEditingKey = false
            keyStatus = "已保存"
            Task { await refresh() }
        } catch {
            keyStatus = "保存失败：\(error.localizedDescription)"
        }
    }

    private func loadSnapshot() {
        let state = loadQuotaPanelSnapshot(from: GLMQuotaSnapshotStore())
        snapshot = state.snapshot
        errorText = state.errorText
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let state = await refreshQuotaPanelSnapshot(
            store: GLMQuotaSnapshotStore(),
            currentSnapshot: snapshot,
            fallbackReason: "未返回额度窗口"
        ) {
            GLMQuotaCollector().collect()
        }
        snapshot = state.snapshot
        errorText = state.errorText
    }
}

extension QuotaStatModel {
    init(_ window: GLMQuotaWindow?) {
        guard let window else {
            self.init(remainingPercent: nil, usedPercent: nil, absoluteText: nil, resetsAt: nil)
            return
        }
        let absolute: String? = {
            if let remaining = window.remaining, let total = window.total {
                return "\(remaining)/\(total)"
            }
            if let remaining = window.remaining, let usage = window.usage {
                return "\(remaining)/\(usage)"
            }
            return nil
        }()
        self.init(
            remainingPercent: window.remainingPercent,
            usedPercent: window.usedPercent,
            absoluteText: absolute,
            resetsAt: window.resetsAt
        )
    }
}
