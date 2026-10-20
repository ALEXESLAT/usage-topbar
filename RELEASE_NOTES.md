# Usage Topbar 0.7.2

修正额度重置分类：使用历史采样当时保存的预定重置时间和用卡记录。提前恢复且完整卡记录未变化时显示特殊重置星标；有用卡证据时显示用卡重置，可靠连续观测到期时显示自动重置。缺测或证据不足的未知记录不强加重置标志和绿条。实时记录与历史回放使用同一规则，不覆盖历史日期或填补缺测值。

Classify resets using the scheduled deadline saved before the reset and card evidence. Early full recovery with complete unchanged cards is special; redeemed-card evidence takes priority, and reliably observed scheduled resets retain their cycle type. Missing evidence does not force reset markers or green bands. Live collection and history replay share the same rules without rewriting historical deadlines.

0.7.2（build 54），Apple Silicon arm64，macOS 13+。针对性分类、回放和历史日期保存检查通过。沿用 ad-hoc 签名，未经过 Apple 公证。
