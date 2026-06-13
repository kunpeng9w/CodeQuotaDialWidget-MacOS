import GLMQuotaCore
import SwiftUI
import WidgetKit

struct GLMQuotaPanelView: View {
    @State private var snapshot: GLMQuotaSnapshot?
    @State private var errorText: String?
    @State private var isRefreshing = false
    @StateObject private var agent = LaunchAgentController(
        label: LaunchAgentLabels.glm.label,
        plistPath: LaunchAgentLabels.glm.plist
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("GLM 额度")
                    .font(.title3.weight(.semibold))
                if let level = snapshot?.level {
                    Text(level.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.14))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(snapshot.map { "更新 \(timeFormatter.string(from: $0.generatedAt))" } ?? "未刷新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LaunchAgentToggleRow(controller: agent)

            HStack(spacing: Theme.cardSpacing) {
                QuotaStatCard(title: "工具类额度", model: QuotaStatModel(snapshot?.timeLimit))
                QuotaStatCard(title: "5h", model: QuotaStatModel(snapshot?.tokensLimit5))
                QuotaStatCard(title: "本周", model: QuotaStatModel(snapshot?.tokensLimitMonth))
            }

            if let message = errorText ?? agent.lastError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            HStack {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("刷新额度")
                    }
                }
                .disabled(isRefreshing)

                Spacer()

                Text("桌面组件每 2 分钟读取快照")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadSnapshot()
            agent.refreshStatus()
        }
    }

    private func loadSnapshot() {
        do {
            snapshot = try GLMQuotaSnapshotStore().load()
            errorText = snapshot?.error
        } catch {
            errorText = "暂无额度快照，请先刷新。"
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let newSnapshot = await Task.detached {
            GLMQuotaCollector().collect()
        }.value

        do {
            let store = GLMQuotaSnapshotStore()

            if newSnapshot.isRefreshFailure, let previous = snapshot ?? (try? store.load()) {
                let reason = newSnapshot.error ?? "未返回额度窗口"
                snapshot = previous
                errorText = "刷新失败，保留 \(timeFormatter.string(from: previous.generatedAt)) 的数据：\(reason)"
                return
            }

            try store.save(newSnapshot)
            WidgetCenter.shared.reloadAllTimelines()
            snapshot = newSnapshot
            errorText = newSnapshot.error
        } catch {
            errorText = "保存额度快照失败：\(error.localizedDescription)"
        }
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

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
}()
