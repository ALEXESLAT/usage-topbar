# Usage Topbar

为 Apple Silicon Mac 打造的液态玻璃风格轻量工具：把 Codex 剩余额度、周期、重置倒计时、points 和整机网速放在窗口边缘与菜单栏。

A lightweight, liquid-glass-style Codex usage companion for Apple Silicon Macs. Native Liquid Glass on macOS 26+; SwiftUI material fallback on earlier supported systems.

**当前版本：0.3.1（build 19） · Apple Silicon（arm64） · macOS 13+**

[下载 DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.dmg) · [下载 ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.zip) · [发布页](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.3.1) · [安装与使用](docs/USAGE.md) · [更新记录](CHANGELOG.md)

![使用生成数据的界面示意图](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-preview.png)

> 本程序及文档由人工智能编写。The software and documentation were written by artificial intelligence.

## 可以做什么

- 每 30 秒读取已登录 Codex 的用量，显示最受限周期的剩余百分比、周期长度及其重置时间。
- 浮层跟随前台 Codex/ChatGPT 窗口的左上边缘，位于该窗口后方；其他应用在前台时隐藏。上方空间不足时隐藏浮层，通过菜单栏查看。
- 用 `CODEX` 指示灯显示用量请求状态；下方上下行速率是整机所选外部网卡的吞吐，不是 Codex 专属流量。
- 从菜单栏立即刷新、显示/隐藏浮层或退出。睡眠时暂停监控，唤醒后重新连接。
- macOS 26+ 使用 Liquid Glass；较早的受支持系统使用 SwiftUI 材质。多屏位置、缩放及安全区域采用系统提供的尺寸。

## 安装

1. 确认使用 Apple Silicon（M 系列）Mac、macOS 13 或更高版本，并已安装、登录可提供 app-server 的 Codex/ChatGPT 桌面应用。**不支持 Intel Mac。**
2. 下载上方 DMG，将 `UsageTopbar.app` 拖入“应用程序”。ZIP 用户解压后同样移动到 `/Applications`。
3. 打开应用，阅读本次启动的数据说明，选择“启动”后才开始实时读取；选择“取消”则退出。无需把账号凭据填进 Usage Topbar。

应用使用 **ad-hoc 签名，未经过 Apple 公证**。若 macOS 拦截首次打开，请先核实下载来源，再按系统提示处理该应用的打开许可。不要关闭 Gatekeeper 或降低全局安全设置。

可用发布页的 [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/SHA256SUMS.txt) 核对下载文件。更新前先退出旧版，再替换“应用程序”内的应用。

## 如何读数

| 显示 | 含义 |
| --- | --- |
| `0%`–`100%` | 最近一次有效读取的剩余额度；按最受限的可用 Codex 周期显示 |
| `--%` | 正在初始化、离线、读取失败或数据不可用；不表示额度已经用完 |
| `points --` | 未取得有效 points 余额 |
| 绿 / 黄 / 红灯 | 用量请求成功 / 正在检查 / 请求失败或本地网络不可用；不是通用网速测试 |
| `↓` / `↑` | 整机吞吐的近似速率；接电约 2 秒采样，电池或低电量模式约 5 秒采样 |

正常刷新期间仍显示最近一次有效值；检测到失败后显示 `--%`。数值不是逐秒更新，也不代表任何模型请求一定能成功。完整操作、故障排查和隐私说明见 [使用指南](docs/USAGE.md)。

## 从源码构建

默认分支提供项目介绍。**构建本次发布请检出 `v0.3.1`；不要把默认分支当作发布源码。**

需要 Apple Silicon Mac、含 macOS 26 或更新 SDK 的 Xcode/Swift 工具链；回归测试还需要 Python 3。编译目标仍为 macOS 13+。

```sh
git clone --branch v0.3.1 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

构建产物位于 `${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app`，仅包含 arm64；构建不会自动安装。源码、管理技能和测试也包含在 [插件包](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-plugin-0.3.1.zip) 中。已发布包内文档保持发布时快照，最新说明以本仓库文档为准。

## 数据与验证范围

Usage Topbar 通过本地 Codex app-server 向 OpenAI 读取用量，在本机计算网卡计数增量及窗口位置。macOS 14+ 且已有屏幕录制权限时，最多每约 3 秒采样一个 12×12 点顶栏区域的平均明暗；否则使用系统外观，不主动申请该权限，不做 OCR。

Usage Topbar 自身不保存用量快照、凭据、网速统计、窗口几何、截图或颜色样本；OpenAI 接收用量请求及正常连接元数据。Codex 自身的存储和账户行为由其设置决定。

在 Apple Silicon / macOS 27.2 上完成原生构建、合成回归与界面渲染：17 项额度、8 项布局、4 项网速断言和 7 类模拟服务生命周期场景通过；12 种明暗/缩放/数值状态渲染通过，安装包架构、版本、签名和校验和已核对。

**尚未实机覆盖旧版 macOS、物理多屏/刘海组合及真实账户长时间运行。** 仓库没有 GitHub Actions 工作流，不宣称 CI 已通过。签名与目标系统声明不等于所有机型均已验证。
