# Usage Topbar 0.8.0 (56) stable release

- Update channels: Stable by default, with a persistent Beta option. Semantic versions plus increasing build numbers prevent downgrades. Switching cancels old candidates; resumed downloads are revalidated. Existing feed, signature, identity and package validation remain enabled.
- Reset classification: full recovery before the previously saved natural deadline with complete unchanged card evidence may infer a special reset across a gap for the same account. Explicit redeemed-card evidence takes priority. Missing evidence or gaps crossing the old deadline remain unknown. Observed unknown recoveries get a green band and circular arrow; natural resets use a clock arrow. Ordinary outages have no reset marker. Replay is derived without rewriting raw history.
- Proxy/reconnection: subprocesses preserve explicit proxy variables and can inherit static system proxy settings. Configuration changes and request errors reconnect. No network settings were changed. PAC and client-internal routing remain limitations.

Review fixes cover resumed downloads bypassing channel filtering, inconsistent metadata being reported as up to date, and error text overlapping the legend. Derived history is cached by revision and account.

This stable release uses the production identity. The local installed app was not replaced. Releases use matching signed channel metadata. Signatures are ad-hoc development signatures, not Developer ID notarization. See the candidate acceptance report for isolated, offscreen and local UI evidence; these do not establish long-running real-account performance. Special resets remain evidence-based inferences without an exact event time across gaps.


## 本地补测与验收限制 / Validation limits

当前353点历史副本重复绘图100次，中位1.56ms、P95 1.69ms；合成4万点中位36.61ms、P95 40.63ms。测量为820×280位图上的单次HistoryChartView.draw，不包含屏幕合成。4万点首次完整派生约4.77ms；低于0.001ms仅为缓存命中。

Current 353-point snapshot: 100 offscreen draws, median 1.56ms, P95 1.69ms. Synthetic 40,000 points: median 36.61ms, P95 40.63ms. These measure one draw into an 820×280 bitmap, excluding display composition. Initial full derivation takes about 4.77ms at 40,000 points; sub-0.001ms values are cache hits only.

15项本地回归、双配置离屏、arm64构建和签名/包检查通过。前台通道点击、实际退出重开、图标前台交互与本版真实下载/安装全流程未验证：菜单栏AX超时，随后Mac连接中断。实际隔离候选浮层已启动并查看。无Developer ID/公证、长期真实账号或PAC路由保证。

15 local test commands, both configurations offscreen, arm64 build and signature/package checks passed. Foreground channel clicks, actual quit/reopen, foreground icon interaction and this version's end-to-end download/install remain unverified due to menu-bar AX timeout followed by connection loss. The isolated candidate floating UI was launched and inspected. No Developer ID/notarization or long-running real-account/PAC guarantees.
