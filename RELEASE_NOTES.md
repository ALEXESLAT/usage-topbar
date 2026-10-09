# Usage Topbar 0.3.1

**简体中文** · [English](RELEASE_NOTES.en.md)

**0.3.1（build 19） · Apple Silicon（arm64） · macOS 13+**

液态玻璃风格的原生 macOS 小工具，把 Codex 的剩余额度、周期、重置倒计时、points 和整机网速放在窗口左上边缘。0.3 系列重点修正读数语义、连接恢复和屏幕布局；本版仅支持 Apple Silicon，不支持 Intel Mac。

## 下载与安装

- [arm64 DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.dmg)：应用、Applications 快捷方式及安装说明。
- [arm64 ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.zip)：同版应用的 ZIP 包。
- [插件与源码](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-plugin-0.3.1.zip)：管理技能、源码及合成回归测试。
- [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/SHA256SUMS.txt)：下载文件校验和。

将 `UsageTopbar.app` 移到 `/Applications`；更新时先退出旧版。已安装并登录的 Codex/ChatGPT 桌面环境需提供可用的 app-server。首次打开后，阅读并确认本次启动的数据说明，才开始读取实时用量。

应用使用 **ad-hoc 签名，未经过 Apple 公证**。macOS 可能拦截首次打开；核实来源后按系统提示处理单应用许可，不要关闭 Gatekeeper 或降低全局安全设置。

[完整安装与使用指南](https://github.com/ALEXESLAT/usage-topbar/blob/main/docs/USAGE.md) · [项目介绍](https://github.com/ALEXESLAT/usage-topbar) · [历史更新](https://github.com/ALEXESLAT/usage-topbar/blob/main/CHANGELOG.md)

## 此次改进

- **读数更明确：** 未知、离线或失败显示 `--%`，不误报为 `0%`；不拿其他模型的额度桶代替 Codex，周期和倒计时与最受限额度对应。
- **恢复更可靠：** 初始化/读取有超时处理，失败和进程退出可重试；匹配响应 ID，限制响应缓冲区，避免旧响应覆盖新状态；睡眠暂停、唤醒重新读取。
- **布局更稳妥：** 按显示器二维位置、缩放和安全区域定位，处理较窄窗口及水平边缘。Codex 上方空间不足时隐藏浮层，通过菜单栏查看。
- **网速更合理：** 按实际采样间隔和每个网卡的基线计算，避免网卡切换、计数回绕或睡眠后的突增；网速是整机数据，不是 Codex 专属流量。
- **保留外观：** macOS 26+ 使用 Liquid Glass，较早的受支持系统使用 SwiftUI 材质；macOS 14+ 且已有权限时才采样极小区域的明暗，否则使用系统外观。

## 已验证与限制

在 Apple Silicon / macOS 27.2 上完成：

- 原生 arm64 构建及回归：17 项额度、8 项布局、4 项网速断言，7 类模拟服务生命周期场景通过。
- 12 种明暗、1×/2×、100%/0%/未知状态的界面渲染通过。
- 包内版本 0.3.1（19）、仅 arm64、最低系统声明 13.0、ad-hoc 签名和 DMG 校验通过；发布附件 SHA-256 与本地产物一致。

**旧版 macOS、物理多屏/刘海组合以及真实账户长时间运行尚未实机覆盖。** 模拟布局和成功编译不等于所有 Mac 均已验证。仓库没有 GitHub Actions 工作流，因此不宣称 CI 通过。

Usage Topbar 自身不保存用量快照、凭据、网速统计或截图；用量请求及正常连接元数据发往 OpenAI。详细数据范围见使用指南。

本次更新双语文档和介绍，并将已发布源码同步到 `main`；程序逻辑、`v0.3.1` 标签及二进制附件保持发布时内容。已发布插件/安装包内的文档是当时快照，最新说明以仓库为准。

> 本程序及文档由人工智能编写。
