# Usage Topbar 0.5.0

[English](RELEASE_NOTES.en.md)

**0.5.0（build 24）· Apple Silicon / macOS 13+**

- 新增菜单“检查更新…”，使用 Sparkle 2.10.0 获取正式签名清单，下载经验证的新版并由用户确认安装、重启。
- 默认不自动检查、下载或安装，不强制重启，不发送系统画像。
- 保存手动显示/隐藏浮层的选择；重启和后续更新保持偏好，已有开机自启状态不变。
- 冻结快照签名、精确身份/版本校验，以及发布前后 ZIP/feed/摘要一致性检查。

**0.4.0 用户需手动安装一次本版**，随后可通过正式签名清单更新。应用内更新需用户确认，不强制重启。原有开机自启状态保留，新用户默认关闭。

**ad-hoc 签名、未经过 Apple 公证。** 浏览器下载带 quarantine 时，Gatekeeper 可能拦截；实际隔离下载评估已观察到拒绝。不能保证其他 Mac 首次打开顺畅，不提供安全绕过步骤。

[DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.dmg) · [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.zip) · [插件/源码](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/usage-topbar-plugin-0.5.0.zip) · [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/SHA256SUMS.txt)

验证包括合成回归、启动、更新策略、元数据、嵌套签名及最终产物验签；隔离真实应用已完成标准 UI、HTTPS/CDN 升级与设置保留。受控下载重试、安装替换失败保留旧包及手动备份恢复已测。**没有自动健康回滚**；Developer ID、公证、全新 Mac、真实登录重启、任意磁盘故障和所有标准 UI 分支未验证。

正式身份和 main feed 不含测试替换；不使用模拟账户。继续沿用已有登录读取额度/卡，仅本机处理整机网速、窗口位置和已有录屏权限下的小区域明暗。无权限降级，不新增权限、不存截图、不识别文字、不兑换卡。退出停止请求与采样。

[更新流程与验证边界](docs/UPDATES.md) · [使用与隐私](docs/USAGE.md)
