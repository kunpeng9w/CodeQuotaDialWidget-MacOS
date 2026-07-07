# Code Quota Dial Widget

> 把 **Codex**、**Claude Code**、**GLM（智谱）**、**Antigravity**、**Sub2API** 的额度与用量做成 macOS 桌面组件和监控面板：总览一屏尽览，桌面组件随时一眼掌握。

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="platform" />
  <img src="https://img.shields.io/badge/Xcode-16%2B-147EFB" alt="Xcode" />
  <img src="https://img.shields.io/badge/Swift-Package-orange" alt="Swift" />
</p>
<p align="center">
  <img src="assets/example_all.png" alt="组件示例" width="800" />
</p>
<p align="center">
  <img src="assets/example_desktop.png" alt="桌面效果" width="800" />
</p>

---

## 目录

- [功能亮点](#功能亮点)
- [安装要求](#安装要求)
- [快速开始](#快速开始)
- [使用指南](#使用指南)
- [常见问题](#常见问题)
- [卸载](#卸载)
- [进阶](#进阶)

---

## 功能亮点

- 📊 **总览首页**：打开 app 即见所有服务的环形额度表盘（自动显示最紧张的窗口）和今日消耗，一屏尽览，点卡片直达详情；数据超过 30 分钟未更新会有橙色过期提示。
- 🖥️ **桌面组件**：每个服务都有对应的桌面小组件，后台每 2 分钟自动抓取并刷新，无需打开 app。
- 🎛️ **服务开关**：设置页一排开关芯片，点亮/熄灭即可控制某个服务是否出现在总览与侧栏；熄灭同时停止它的后台刷新，即时生效。
- 📈 **消耗统计**：基于官方 `ccusage` 展示今日 / 本周 / 本月 / 总计的 token 与费用、日历热力图与本周趋势；本机 **ZCode CLI** 用量自动并入，还可聚合多台远端机器（SSH）。
- 🌐 **Sub2API 统计**：支持多个中转站账号，汇总查看限额、当日消耗、趋势与模型明细。
- 💰 **模型价格**：各模型输入 / 缓存 / 输出单价与总花费一览，价格每日联网更新、离线回落缓存。
- ⚙️ **零配置安装**：一条命令完成构建、签名、安装；代理、远端主机等全部在 app 内修改，改完即生效，无需重装。

## 安装要求

本项目在**本机从源码构建**（不是下载现成 app），每台机器用自己的签名身份编译安装。

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS 14+ |
| 构建工具 | Xcode 16+（App Store 下载） |
| 签名身份 | 本机有一张 Apple Development 证书（免费，见下方说明） |
| Node.js | 8.x+（消耗统计通过 `npx ccusage` 抓取数据） |

<details>
<summary><b>没有签名身份？免费获取只需一步</b></summary>

打开 **Xcode → Settings → Accounts**，用任意 Apple ID 登录，Xcode 会自动签发免费的 Apple Development 证书（无需付费开发者账号）。验证是否已有：

```bash
security find-identity -v -p codesigning
```

列出至少一条 `Apple Development: ...` 即可，安装脚本会自动选用。若列出多条，安装时用环境变量指定其一（见[进阶](#进阶)）。

</details>

**各服务的凭据要求**（缺少某项只影响对应服务，不影响其它）：

- **Codex**：本机 Codex 已用 ChatGPT 账号登录。
- **Claude**：本机 Claude Code 已登录。
- **GLM**：在 app 的 GLM 面板头部点「设置 API Key」，弹窗中粘贴保存（保存后不再回显，可随时点「修改」更换）。
- **Antigravity**：本机 Antigravity 已登录且正在运行。
- **Sub2API**：在 app 的 Sub2API 面板添加中转站的 Base URL 和 API Key。

## 快速开始

```bash
cd CodeQuotaDialWidget
./script/install.command
```

脚本自动完成签名检测、构建、安装到 `/Applications`、注册后台刷新任务，完成后自动打开 app。

以后更新代码后重新执行同一条命令（或 `./script/rebuild-local.command`）即可；换新机器也是同样一条命令，无需迁移任何配置。

## 使用指南

### 主窗口

启动后落在**总览**页；左侧边栏切换：

- **总览**：所有服务的额度表盘 + 今日消耗，点卡片进详情，右上角「刷新」可一键刷新全部。
- **Codex / Claude / GLM / Antigravity**：各服务的额度详情——环形表盘、已用比例、重置时间；Codex / Claude / GLM 面板底部还有该服务本周消耗趋势图。
- **Sub2API**：账号管理与限额、当日消耗、近 7 天趋势、模型明细。
- **消耗统计**：日历热力图（点日期看当日明细）、区间统计、本周趋势、模型分布；可按本机 / 远端 / 各 CLI 切换范围。
- **模型价格**：单价明细表与总花费。
- **设置**：服务显示开关、网络代理、远端 SSH 主机、ZCode 开关。

每个面板右上角有**刷新**按钮，头部有**后台自动刷新**开关；面板里的数字文本都可以选中复制。

### 首次配置（都在 app 内完成）

1. **GLM Key**：GLM 面板头部 →「设置 API Key」→ 粘贴保存。
2. **Sub2API 账号**：Sub2API 面板 →「添加账号」→ 填 Base URL 和 API Key，支持多账号。
3. **代理**（可选）：默认留空即自动跟随 macOS 系统代理——输入框的灰色占位符会实时显示当前系统代理；需要覆盖时再手填。
4. **远端多端统计**（可选）：设置页「远端 SSH 主机」每行填一个 host。要求本机到远端免密 SSH，且远端装有 `ccusage`；连不上的主机会自动跳过。
5. **服务开关**（可选）：设置页「主页面显示」熄灭不用的服务，它会从总览和侧栏消失并停止后台刷新。

### 添加桌面组件

1. 右键桌面空白处 →「编辑小组件」。
2. 搜索 **Code Quota Dial**。
3. 把想要的组件拖到桌面即可，组件每 2 分钟自动更新。

## 常见问题

### 1. 装好后组件/面板没有数据？

多数是对应服务的凭据没就绪，对照[凭据要求](#安装要求)逐项检查：Codex / Claude 是否已登录、GLM Key 是否已填、Antigravity 是否在运行、代理是否可用。

<details>
<summary>进一步排查：查看日志与手动触发刷新</summary>

```bash
# 查看某个服务的抓取日志（codex / claude / glm / antigravity / sub2api / usage）
tail -n 100 Runtime/codex/logs/refresh.err.log

# 手动触发一次后台刷新
launchctl kickstart -k "gui/$(id -u)/local.codex-quota-dial.refresh"
launchctl kickstart -k "gui/$(id -u)/local.claude-quota-dial.refresh"
launchctl kickstart -k "gui/$(id -u)/local.glm-quota-dial.refresh"
launchctl kickstart -k "gui/$(id -u)/local.antigravity-quota-dial.refresh"
launchctl kickstart -k "gui/$(id -u)/local.sub2api-quota-dial.refresh"
launchctl kickstart -k "gui/$(id -u)/local.usage-quota-dial.refresh"
```

仍无数据时可卸载重装重置：`./script/uninstall.command` 后再 `./script/install.command`。

另外：Claude Code 的本地登录令牌约 8 小时过期一次，本项目检测到过期会自动触发一次无消耗的刷新来续期，无需人工干预。

</details>

### 2. App 里数据是新的，桌面组件还是旧的？

组件由系统按约 2 分钟节奏刷新，系统繁忙时可能略有延迟；稍等片刻，或把组件移除后重新添加。

### 3. 数据和 Key 存在哪里，安全吗？

GLM Key、Sub2API Key 等保存在本机 `~/Library/Application Support/CodeQuotaDial/runtime-config.json`（文件权限 600，仅当前用户可读），不会上传任何服务器。「保存后隐藏」指界面不再回显，磁盘上为明文，请自行留意备份与共享场景。

## 卸载

```bash
./script/uninstall.command                          # 标准卸载
./script/uninstall.command --include-project-build  # 连同本地构建产物一起清理
```

## 进阶

<details>
<summary>安装脚本的环境变量覆盖</summary>

| 环境变量 | 何时需要 |
| --- | --- |
| `SIGNING_IDENTITY` / `TEAM_ID` | keychain 里有多个 Apple Development 身份、自动检测无法判断时（脚本会报错并列出候选） |
| `INSTALL_BASE` | 改安装目录（默认 `/Applications`） |
| `REFRESH_INTERVAL` | 改后台数据抓取间隔秒数（默认 `120`） |
| `PATH_PREFIX` | 改后台工具的可执行文件查找路径前缀 |

```bash
# 例：多个签名身份时指定其一
SIGNING_IDENTITY="Apple Development: you@example.com (XXXXXXXXXX)" ./script/install.command
# 例：改刷新间隔为 60 秒
REFRESH_INTERVAL=60 ./script/install.command
```

</details>
