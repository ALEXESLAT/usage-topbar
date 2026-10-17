# Usage Topbar 0.6.26

[English](RELEASE_NOTES.en.md)

**0.6.26（build 51）· Apple Silicon / macOS 13+**

- 新增本机额度历史：四天概览、可滚动七天详情、悬停读数及重置事件；保留三个月的真实记录和明确的数据缺口。
- 保持原始历史数据，优化曲线与渐变缓存；隐藏和最小化的历史窗口在重新显示时刷新。
- 历史快照后台串行保存，合并写入期间的新变化；失败后重试，睡眠与退出等待最后快照保存。
- 正式版首次启动可安全接续 Testing 的真实历史：校验、去重、保留正式冲突记录并创建迁移备份。测试偏好和模拟数据不导入。

**0.5.0 用户在原应用中选择“检查更新…”，确认下载、安装和重启即可。** 不必先手动替换旧应用。0.4.0 及更早版本需手动安装。正式应用仍使用原身份、偏好域和签名更新通道；Testing 保持独立。

[DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/UsageTopbar-0.6.26-macOS-arm64.dmg) · [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/UsageTopbar-0.6.26-macOS-arm64.zip) · [插件/源码](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/usage-topbar-plugin-0.6.26.zip) · [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/SHA256SUMS.txt)

本机合成回归覆盖历史、迁移、图表、生命周期、启动、更新策略及包元数据；发布包使用原有公钥对应签名，并校验身份、精确版本/build及下载摘要。主线程保存路径优化不代表整机 CPU 或续航同比改善。真实长期运行、旧系统和物理触控板尚未全面验收。

应用为 **ad-hoc 签名、未经过 Apple 公证**，首次安装仍可能被系统拦截；没有自动健康回滚。应用内更新由用户发起并确认，不自动下载或安装。

[更新流程与恢复边界](docs/UPDATES.md) · [使用与隐私](docs/USAGE.md)
