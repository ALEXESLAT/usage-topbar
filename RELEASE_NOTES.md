# Usage Topbar 0.7.3

收紧重置分类的证据边界：历史采样继续保存当时的预定重置时间；缺测期间即使前后卡列表相同，也不据此推断未用卡或特殊重置。连续新鲜观测支持的提前重置、到期重置，以及明确用卡证据仍按对应类型显示。未知记录不强加标志或绿条，历史回放使用同一规则。

修复测试中固定旧版本号的问题，使用独立版本元数据验证，并将恢复与回放检查接入 GitHub Actions。

Tighten reset evidence boundaries: matching card snapshots across an unseen interval do not prove that no card was used. Preserve each sample's scheduled deadline, classify supported fresh observations and redeemed-card evidence, and leave uncertain history unmarked. Fix stale version assertions using independent fixture metadata and include recovery/replay checks in CI.

0.7.3（build 55），Apple Silicon arm64，macOS 13+。沿用 ad-hoc 签名，未经过 Apple 公证。
