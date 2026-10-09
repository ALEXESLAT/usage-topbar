# Usage Topbar 0.4.0

**简体中文** · [English](RELEASE_NOTES.en.md)

**0.4.0 (build 20) · Apple Silicon (arm64) · macOS 13+**

- 紧凑浮窗：百分比整体居中，pts 对齐百分比实际左缘，卡片信息在上、网速在下，菜单栏使用 Codex 标志。
- 使用真实重置时间计算倒计时；显示可用重置卡数量及最近到期日期 `Exp. MM/dd`，资料缺失显示 `--`。
- 首次获取和断联恢复时，数字与进度条同步以约 0.8 秒先快后慢地到达实际值；普通刷新不重播，适配减少动态效果。
- 打开即开始已披露范围的监控，取消每次启动确认；可选开机自启，新用户默认关闭，保留已有系统状态。
- 后台及手动隐藏时改为每秒保底检查；前台与空间不足自动隐藏仍每 0.2 秒检查，事件立即唤醒。显示去重和字体测量缓存减少重复工作。

- [DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.dmg)
- [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.zip)
- [Plugin / source](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/usage-topbar-plugin-0.4.0.zip)
- [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/SHA256SUMS.txt)

更新前先退出旧版，将应用放入 `/Applications`。需要已登录且提供 app-server 的 Codex/ChatGPT。打开即开始已披露范围的监控，不再要求每次启动确认。

本版 **ad-hoc 签名，未经过 Apple 公证**，不支持 Intel。首次运行遵循 macOS 单应用许可提示，不关闭 Gatekeeper。

验证：本机 arm64 优化构建、合成额度/卡片/倒计时/连接/布局回归、启动与恢复动画/自启控制器测试、明暗及 1×/2× 合成渲染；打包时核对版本、签名和校验和。此前同一功能源码的安装测试覆盖普通重复打开、退出清理和实时启动；发布安装另行核对版本与运行状态。

限制：减少动态效果、断联、无录屏权限及自启注册主要使用合成测试；未执行重启登录、旧系统、物理多屏/刘海组合或长期电池测试。不宣称全应用节能比例，不支持可靠的跨进程卡片消费检测，不兑换真实卡。

使用现有登录读取 OpenAI 额度/卡信息；本机计算整机网速、窗口位置和已有权限时的极小区域明暗。无权限时降级，不主动请求新权限、不做 OCR、不保存截图；退出停止请求和采样。

[安装与隐私](docs/USAGE.md) · [更新记录](CHANGELOG.md)

> 本程序及文档由人工智能编写。
