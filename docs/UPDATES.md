# 应用内更新 — 0.5.0（24）

[English](UPDATES.en.md)

0.5.0 首次加入正式手动更新通道。**0.4.0 没有更新器，需要手动安装一次 0.5.0；以后使用菜单“检查更新…”。** 更新使用固定的 [main 签名清单](https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml)，仅接受本仓库 HTTPS Release ZIP 和递增整数 build。正式版和测试版通过同一签名清单内的通道字段区分，见下文。

## 用户流程与限制

手动检查 → 发现新版 → 用户选择下载 → ZIP 验签 → 用户确认安装和重启 → 恢复设置。可以取消检查或下载、跳过版本；同意安装后的“稍后重启”可能在退出时完成安装，不等于取消下载。没有自动检查、自动下载、强制重启或系统画像。未知更新来源、错误签名及降级会被拒绝。

当前为 **ad-hoc 签名，未使用 Developer ID，未经过 Apple 公证**。真实 Edge 下载和保留 quarantine 的解压应用曾被本机 Gatekeeper 评估拒绝；首次安装在其他 Mac 上可能被拦截，不能保证直接打开。若系统阻止，请停止并由用户处理，不提供移除隔离标记、关闭 Gatekeeper 或其他安全绕过步骤。

手动显隐保存在稳定偏好域 `local.alex.usage-topbar` 的 `overlay.userHidden`。从 0.4.0 首次升级时没有旧的显隐偏好，默认显示；自动避让是临时状态，演示不写入偏好。位置、配色和尺寸由当前环境计算。macOS 保存登录项状态，更新不注册或注销；真实重启登录尚未测试。应用使用已有 Codex app-server 登录，不复制、存储或更改凭据。

## 验证与恢复边界

- 独立测试通道用真实应用和 Sparkle 标准界面完成 GitHub HTTPS/CDN 下载、验签、安装重启、设置保留及实际 AppDelegate 子进程清理；账户数据使用模拟服务器。
- 已测检查/下载取消、跳过、无新版、网络错误、错误签名、下载中断重试、辅助程序缺失和准备安装后的受控替换失败。失败保留旧包；受控替换失败后验证旧包签名、启动和设置仍正常。
- 新版启动失败后 **没有自动健康回滚**。只验证了隔离副本从已知可运行、签名完整的备份手动恢复；不能保证断电、磁盘损坏等任意故障可恢复。恢复前须确认应用与安装器已退出，保留失败包，不删除偏好。
- 不把可编程宿主测试当作所有标准 UI 分支通过；Developer ID、公证、全新 Mac、旧系统、真实登录/注销/重启和长期真实账户运行未覆盖。
- 从 0.7.3 起，固定 Sparkle 校验器补丁在安装前拒绝错误 Bundle ID、缺失字段或包/feed build 不一致，且保留原签名验证。旧版尚未升级时仍依赖原更新器，因此首次升级必须继续经过发布端精确验签。签名不保证最新；历史有效清单仍可能被重放。私钥泄露意味着发布权失守。

## 维护者发布步骤

1. 递增版本和 build，运行回归、启动、更新策略、元数据和相关安装测试。正式身份为 `local.alex.usage-topbar`；禁止把测试身份、测试 feed 或模拟 app-server 放进正式 app。
2. 用 `USAGE_TOPBAR_CHANNEL=release USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh` 构建并验证 arm64、最低系统、嵌套代码签名及隐私内容。用 `ditto -c -k --keepParent` 打包最终 ZIP。
3. 运行 `scripts/sign-update.py` 的身份/精确版本检查。加 `--sign` 才用现有钥匙串账户 `ALEXESLAT.usage-topbar` 签署冻结快照；输出 SHA-256，文件在检查/签名期间变化则拒绝。私钥不导出、不传环境变量、不上传 CI，不常规生成或轮换密钥。
4. 使用固定 Sparkle 工具生成签名清单：
   ```sh
   SPARKLE=$(scripts/fetch-sparkle.sh)
   "$SPARKLE/bin/generate_appcast" --account ALEXESLAT.usage-topbar --maximum-deltas 0 --download-url-prefix "https://github.com/ALEXESLAT/usage-topbar/releases/download/v$VERSION/" "$RELEASE_DIR"
   python3 scripts/verify-update-release.py "$ZIP" "$APPCAST" --version "$VERSION" --build "$BUILD"
   ```
   最终门槛只用公钥验证两种签名，并绑定身份、精确版本/build、URL、长度。保存输出的 ZIP 和 feed 摘要；签名后不得改写产物。
5. 发布精确提交的资产，重新下载，再运行：
   ```sh
   python3 scripts/verify-update-release.py "$DOWNLOADED_ZIP" "$DOWNLOADED_APPCAST" --version "$VERSION" --build "$BUILD" --expected-sha256 "$ZIP_SHA256" --expected-feed-sha256 "$FEED_SHA256"
   ```
   先确认 ZIP 公开可下载且一致，再启用对应的 main 签名清单。核验标签、CI、Release 状态及本机菜单。保留已知可运行回滚包，不覆盖旧不可变资产。
6. 正式发布、密钥生成或导出仍需用户明确授权；已有本次授权不重复索取。构建本身不安装或发布。

更新请求仅向 GitHub/CDN 发送普通 HTTP/连接元数据，不附加账户、额度、卡或凭据；远程发布说明、JavaScript 和画像关闭。签名清单验证失败时不允许超时降级。

[官方接入与安全模型](https://sparkle-project.org/documentation/) · [安全设置](https://sparkle-project.org/documentation/customization/) · [固定版本验证源码](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SUUpdateValidator.m)

## 正式版与测试版更新通道

菜单“更新通道”显示当前版本和已选通道。默认正式版，选择保存在 `updates.channel`，重开保持。测试版可能不稳定；它同时接收兼容的新测试版和正式版，没有测试候选时仍可更新正式版。无任何合格新版时由 Sparkle 显示无更新；网络/签名错误保持当前安装并可重试。独立的 `UsageTopbar Testing.app` 开发构建仍禁用更新器；公开 beta 使用正式 Bundle ID、真实历史和 release 构建配置，避免产生第二套用户数据。

同一个签名 `main/updates/appcast.xml` 中，正式版不带 `sparkle:channel`，并声明 `<sparkle:releaseStatus>published</sparkle:releaseStatus>`；测试版带 `<sparkle:channel>beta</sparkle:channel>` 和 `<sparkle:releaseStatus>prerelease</sparkle:releaseStatus>`，版本使用如 `1.2.0-beta.1` 的 SemVer 后缀。草稿、未知状态、缺失或不一致元数据均排除。0.8.0正式清单包含此状态字段；后续候选必须按下述流程发布。

先由 Sparkle 排除不兼容系统/硬件，再按 SemVer（包括数字预发布段）选择最新候选；同时要求整数 build 严格增加，营销版本不降低。正式版高于同版本 beta，`beta.10` 高于 `beta.2`，`+build` 元数据不影响版本顺序。切回正式版不会降级；若已装 beta 高于最新正式版，会等待更高版本的正式发布。

切换立即保存选择，使旧会话失效，并通过 Sparkle 实际取消/关闭回调清除旧候选；旧会话结束后重新检查。旧回调不能覆盖新通道。已进入不可撤销的安装/稍后重启阶段则拒绝切换，并保持原选择，需安装结束后再改。更新仍需用户确认下载和安装，无后台自动更新。

### 最小 beta 发布流程（本次未执行）

1. 使用正式身份、release 配置和递增的全局 build，设置 SemVer 预发布版本；完成测试和包校验。
2. 在发布工作目录生成包含稳定项与 beta 项的清单：beta 新项使用 `generate_appcast --channel beta`，正式项用默认通道。补入对应 `sparkle:releaseStatus`，保留版本绑定的内嵌说明、架构和系统要求。使用现有账户执行 `sign_update --account ALEXESLAT.usage-topbar appcast.xml` 重新签名最终清单；签名后不再改写。
3. `verify-update-release.py` 会检查通道/状态/版本一致性及原有两类签名、身份、URL、长度。发布实际非 draft 的 GitHub prerelease 后，保存公开 REST Release JSON；下载复验时加 `--release-json release.json`，核对 `draft=false`、`prerelease=true` 和精确标签。正式版对应 `prerelease=false`。最后才启用同一 main 签名清单，绝不将草稿加入 feed。
4. 本次只用模拟数据验证，不创建 release、不使用私钥、不安装。测试：`python3 tests/run-updater.py`、`python3 tests/test-update-channels.py`、`python3 tests/run-release-config.py`。实际切换通道、下载/安装的标准 UI 验收尚未进行。
