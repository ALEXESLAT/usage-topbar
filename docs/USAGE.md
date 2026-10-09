# 安装与使用 Usage Topbar

**简体中文** · [English](USAGE.en.md)

本文适用于 **0.4.0（20）**，仅支持 Apple Silicon（arm64）、macOS 13+。[返回项目介绍](../README.md) · [发布下载](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.4.0)

## 安装与更新

1. 安装并登录 Codex/ChatGPT 桌面应用，确保其提供可用的 Codex app-server。
2. 下载 [arm64 DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.dmg) 或 [arm64 ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.zip)。更新时先在 Usage Topbar 菜单栏菜单中退出旧版。
3. 将 `UsageTopbar.app` 放入 `/Applications`。不要直接把 DMG 内的应用作为长期运行副本。
4. 打开应用。首次可能出现 macOS 开发者验证提示：本版为 ad-hoc 签名、未公证。核实来源后遵循系统的单应用打开提示，不关闭 Gatekeeper，不修改全局安全设置。
5. 本版打开即开始已授权范围的监控，不再显示启动确认。不会自动添加登录项、获取新凭证或自动申请系统权限；退出即停止采样和请求。

下载校验：在下载目录执行下列命令，将结果与发布页 [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/SHA256SUMS.txt) 中同名文件的一行比较。

```sh
shasum -a 256 UsageTopbar-0.4.0-macOS-arm64.dmg
```

无需输入 API key，也无需向 Usage Topbar 复制账号凭据。应用会尝试已注册的 Codex/ChatGPT 安装位置及常见 CLI 路径；找不到时显示 `Codex not found`。

## 日常操作

- 菜单栏的 Codex 标志显示剩余百分比；菜单可“立即刷新”“显示/隐藏浮层”或“退出 Usage Topbar”。
- 实时模式只在 Codex/ChatGPT 位于前台且窗口上方有足够空间时显示浮层。切换其他应用、最大化/全屏或接近屏幕顶边时，浮层可能隐藏；菜单栏仍可用，但 macOS 可能在拥挤菜单栏中隐藏额外项目。
- 浮层显示最受限 Codex 周期及其重置倒计时；`points` 是返回的余额。`--%` 表示未知/不可用，`0%` 才表示有效读数为零。
- 绿灯表示最近一次有效用量请求成功；黄灯表示检查中；红灯表示请求失败或本地网络不可用。网速变化不能把失败的用量请求变成成功。
- `↓`/`↑` 为整机所选外部网卡的速率，不测网速上限、不检查流量内容，也不表示 Codex 独占流量。

用量一般每 30 秒刷新。手动刷新在初始化期间或已有请求待回应时不会额外叠加请求；失败、进程退出和超时会按对应逻辑恢复。睡眠暂停监控，唤醒后重新读取，避免继续展示睡眠前的百分比。

卡片图标旁显示可用重置卡数量，`Exp. MM/dd` 为最近到期日期（本地时区）；`Exp. --` 表示未知，`Exp. none` 表示已知全部无到期限制。详情不完整时不会猜测日期。本应用不会兑换卡，也不能可靠判断另一进程是否刚消费了卡。

首次获取及断联恢复后约 0.8 秒从零填充到实际百分比；普通刷新不重播，减少动态效果时直接显示结果。倒计时按绝对重置时间计算。

## 管理命令

以下命令从 `v0.4.0` 源码或插件包的根目录执行。`start` 和 `demo` 使用 **已安装在 `/Applications/UsageTopbar.app` 的版本**。

```sh
scripts/usage-topbar.sh status
scripts/usage-topbar.sh demo
scripts/usage-topbar.sh start
scripts/usage-topbar.sh preview
scripts/usage-topbar.sh build
```

| 命令 | 实际行为 |
| --- | --- |
| `status` | 返回 `running`、`stopped`；进程查询受限时返回 `unknown` 和错误，不能据此认定已停止 |
| `demo` | 新开一个生成数据的示例，不读取账号用量、真实网速或窗口颜色；可从该实例菜单退出 |
| `start` | 打开已安装应用并直接开始已披露范围的监控 |
| `preview` | 输出仓库中已有预览图的路径，不重新渲染 |
| `build` | 生成临时开发 app，不覆盖 `/Applications` 中的安装 |
| `stop` | 停止所有名为 `UsageTopbar` 的进程；只想退出单个示例时优先用其菜单 |

同样的命令可通过 `skills/manage-usage-topbar/scripts/control.sh` 调用。已明确授权无感启动时，不重复索取同一范围的同意；新增数据、接收方或权限仍需另行授权。数据范围见 [本地数据说明](../skills/manage-usage-topbar/references/data-contract.md)。

## 常见情况

| 情况 | 处理 |
| --- | --- |
| 找不到已安装应用 | 确认 `UsageTopbar.app` 位于 `/Applications`；运行 `build` 不等于安装 |
| `Codex not found` | 确认桌面应用已安装且含可执行 CLI；自定义 CLI 的开发者可在直接启动进程时设置 `CODEX_BINARY` |
| `--%`、红灯或超时 | 检查 Codex 登录和网络，再尝试“立即刷新”；未知不代表额度耗尽 |
| 有菜单栏但无浮层 | 将 Codex 切到前台、向下移动窗口留出顶部空间，并确认未手动隐藏 |
| 菜单栏找不到 Codex 标志 | 检查是否启动成功；菜单栏空间不足时由 macOS 决定哪些项目可见 |
| 明暗未随窗口变化 | macOS 13 或没有既有屏幕录制权限时使用系统外观，这是预期降级，不必为使用本应用更改权限 |

开发者指定已有 CLI 的例子（直接开始监控，不新增账号凭据）：

```sh
CODEX_BINARY="/absolute/path/to/codex" /Applications/UsageTopbar.app/Contents/MacOS/UsageTopbar
```

## 卸载

先从 Usage Topbar 菜单栏菜单退出应用，再将 `/Applications/UsageTopbar.app` 移到废纸篓。若曾开启“开机自启”，先在菜单中关闭，或从系统登录项移除。默认不注册登录项。

卸载 Usage Topbar 不需要删除 Codex/ChatGPT、退出其账号或删除其账户数据。不要为卸载本工具清理 Codex 的凭据、配置和历史记录。

## 反馈问题

在 [GitHub Issues](https://github.com/ALEXESLAT/usage-topbar/issues) 报告问题。建议提供 Usage Topbar 版本/构建号、macOS 版本、Apple Silicon 型号、是否连接外部显示器、复现步骤、预期与实际结果，以及可见错误文字。不必提供设备序列号。

Issues 是公开的。不要提交账号凭据、API key、访问令牌、个人用量/余额快照或未经检查的日志。截图前请遮蔽账号、任务内容及其他隐私；不能安全脱敏时，仅用文字描述即可。当前没有自动上传诊断数据的功能。

## 隐私与兼容性

实时模式读取 Codex 用量、重置时间和 points，在本地计算网卡计数增量及 Codex 窗口位置。macOS 14+ 且已有屏幕录制权限时，对极小顶栏区域计算平均明暗；不主动请求权限、不做 OCR。用量请求和正常连接元数据发往 OpenAI，网卡统计、窗口几何和颜色样本不发给第三方。

Usage Topbar 自身不持久化这些数据或凭据。退出时停止监控；Codex 自身的数据处理由其设置决定。

最低系统声明为 macOS 13，macOS 26+ 使用 Liquid Glass，较早受支持系统使用 SwiftUI 材质。已验证范围与未覆盖项目见 [发布说明](../RELEASE_NOTES.md)。Intel Mac 不在 0.4.0 支持范围内。

- 菜单中的“开机自启”默认关闭，仅在用户点击时向 macOS 注册登录项；待系统批准时显示对应状态，不自动批准。再次点击可取消注册。
