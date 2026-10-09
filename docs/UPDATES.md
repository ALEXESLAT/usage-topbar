# 应用内更新 — 0.5.0（24）

[English](UPDATES.en.md)

0.5.0 首次加入正式手动更新通道。**0.4.0 没有更新器，需要手动安装一次 0.5.0；以后使用菜单“检查更新…”。** 更新使用固定的 [main 签名清单](https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml)，仅接受本仓库 HTTPS Release ZIP 和递增整数 build。测试预发布保留在独立分支，不是正式通道。

## 用户流程与限制

手动检查 → 发现新版 → 用户选择下载 → ZIP 验签 → 用户确认安装和重启 → 恢复设置。可以取消检查或下载、跳过版本；同意安装后的“稍后重启”可能在退出时完成安装，不等于取消下载。没有自动检查、自动下载、强制重启或系统画像。未知更新来源、错误签名及降级会被拒绝。

当前为 **ad-hoc 签名，未使用 Developer ID，未经过 Apple 公证**。真实 Edge 下载和保留 quarantine 的解压应用曾被本机 Gatekeeper 评估拒绝；首次安装在其他 Mac 上可能被拦截，不能保证直接打开。若系统阻止，请停止并由用户处理，不提供移除隔离标记、关闭 Gatekeeper 或其他安全绕过步骤。

手动显隐保存在稳定偏好域 `local.alex.usage-topbar` 的 `overlay.userHidden`。从 0.4.0 首次升级时没有旧的显隐偏好，默认显示；自动避让是临时状态，演示不写入偏好。位置、配色和尺寸由当前环境计算。macOS 保存登录项状态，更新不注册或注销；真实重启登录尚未测试。应用使用已有 Codex app-server 登录，不复制、存储或更改凭据。

## 验证与恢复边界

- 独立测试通道用真实应用和 Sparkle 标准界面完成 GitHub HTTPS/CDN 下载、验签、安装重启、设置保留及实际 AppDelegate 子进程清理；账户数据使用模拟服务器。
- 已测检查/下载取消、跳过、无新版、网络错误、错误签名、下载中断重试、辅助程序缺失和准备安装后的受控替换失败。失败保留旧包；受控替换失败后验证旧包签名、启动和设置仍正常。
- 新版启动失败后 **没有自动健康回滚**。只验证了隔离副本从已知可运行、签名完整的备份手动恢复；不能保证断电、磁盘损坏等任意故障可恢复。恢复前须确认应用与安装器已退出，保留失败包，不删除偏好。
- 不把可编程宿主测试当作所有标准 UI 分支通过；Developer ID、公证、全新 Mac、旧系统、真实登录/注销/重启和长期真实账户运行未覆盖。
- 可信密钥签出的错误 Bundle ID 或包/feed 精确 build 错配，Sparkle 的 ad-hoc 路径可能接受。发布者的精确检查降低误签风险，不是独立客户端身份边界。签名不保证最新；历史有效清单仍可能被重放。私钥泄露意味着发布权失守。

## 维护者发布步骤

1. 递增版本和 build，运行回归、启动、更新策略、元数据和相关安装测试。正式身份为 `local.alex.usage-topbar`；禁止把测试身份、测试 feed 或模拟 app-server 放进正式 app。
2. 用 `USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh` 构建并验证 arm64、最低系统、嵌套代码签名及隐私内容。用 `ditto -c -k --keepParent` 打包最终 ZIP。
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
