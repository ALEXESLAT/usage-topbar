# Usage Topbar 0.8.0（56）正式版

- 更新通道：默认正式版，可选择测试版并保持选择；使用语义版本和递增构建号防止降级。切换会取消旧候选，恢复下载也重新检查通道。继续使用原有签名、身份与包校验。
- 重置判断：同账号额度恢复至100%、尚未到旧预定自然重置时间且完整卡证据一致时，可跨断档推断特殊重置。明确用卡优先；跨旧日期或证据缺失保持未知。未知的已观察恢复显示绿条和回转箭头，自然重置使用时钟回转，普通断网不标记重置。历史只派生重算，不覆盖原始记录。
- 代理与重连：子进程继承明确代理环境并读取系统静态代理；配置变化及请求错误可重新连接。未修改系统网络设置；PAC和仅由特定客户端内部处理的路由不能由此保证支持。

审查修复了恢复下载绕过通道过滤、元数据不一致误报最新、错误文字遮挡图例；历史派生缓存按数据版本与账号失效。

本版使用正式发布身份；本机未替换安装。正式与测试发布使用对应的已签名发布元数据。签名为开发用ad-hoc，不是Developer ID公证。隔离模拟、离屏及本地验收范围见候选验收报告，不能代替真实账号长期运行体验。特殊重置属于按上述证据规则的推断，不代表知道断档中的精确事件时刻。


## 本地补测与验收限制 / Validation limits

当前353点历史副本重复绘图100次，中位1.56ms、P95 1.69ms；合成4万点中位36.61ms、P95 40.63ms。测量为820×280位图上的单次HistoryChartView.draw，不包含屏幕合成。4万点首次完整派生约4.77ms；低于0.001ms仅为缓存命中。

Current 353-point snapshot: 100 offscreen draws, median 1.56ms, P95 1.69ms. Synthetic 40,000 points: median 36.61ms, P95 40.63ms. These measure one draw into an 820×280 bitmap, excluding display composition. Initial full derivation takes about 4.77ms at 40,000 points; sub-0.001ms values are cache hits only.

15项本地回归、双配置离屏、arm64构建和签名/包检查通过。前台通道点击、实际退出重开、图标前台交互与本版真实下载/安装全流程未验证：菜单栏AX超时，随后Mac连接中断。实际隔离候选浮层已启动并查看。无Developer ID/公证、长期真实账号或PAC路由保证。

15 local test commands, both configurations offscreen, arm64 build and signature/package checks passed. Foreground channel clicks, actual quit/reopen, foreground icon interaction and this version's end-to-end download/install remain unverified due to menu-bar AX timeout followed by connection loss. The isolated candidate floating UI was launched and inspected. No Developer ID/notarization or long-running real-account/PAC guarantees.
