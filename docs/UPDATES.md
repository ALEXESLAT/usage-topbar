# 应用内更新（0.5.0 开发中，未发布）

[English](UPDATES.en.md)

当前正式版仍为 0.4.0。开发版 0.5.0（21）已接入 Sparkle 2.10.0，并经明确批准建立专用 Ed25519 更新签名密钥。源码只包含 `app/update-public-key.txt` 公钥，私钥留在维护者登录钥匙串，账户 `ALEXESLAT.usage-topbar`。本轮未导出私钥、未上传 CI、未发布更新清单或新版。

**尚不能宣称正式升级链路全部验证通过。** 隔离测试中，同一可信密钥签名但更改 Bundle ID、或实际包版本高于清单版本的包，会被 Sparkle ad-hoc 路径接受。已增加本项目签名前身份/精确版本校验，防止误签；它不是客户端运行时的额外包身份校验。该限制需在正式发布前明确处理，不把它报告为“拒绝成功”。

## 普通安装者怎么更新

1. 现有 0.4.0 没有更新器，需要手动安装一次未来正式发布的带更新器版本；本轮开发包不是新的正式下载。
2. 此后通过菜单“检查更新…”主动查询；有兼容新版时，在 Sparkle 标准界面选择下载，再确认安装和重启 UsageTopbar。
3. 可以取消检查/下载或跳过版本。已同意安装后的“稍后重启”与取消下载不同，可能在退出时完成安装。
4. 如果维护者只上传 GitHub Release、没有发布配套的有效签名 appcast，应用内不会自动获得该版本。没有新版与网络/签名错误必须分别显示。

这是下载替换后重启，不是运行中的 Swift 代码热替换。不会强制重启或后台自动下载；旧版在验证前不应被替换。新版启动崩溃后自动回滚尚未实现，不作此承诺。

## 维护者今后的发布步骤

以下是未来发布流程，**不代表本轮已授权正式发布**：

1. 递增 `CFBundleVersion`，同步展示版本、文档和源码；运行回归、更新策略及安装测试。密钥已经存在，不再运行生成/轮换命令。
2. `USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh` 构建。脚本默认读取仓库公钥；验证框架/辅助程序/应用嵌套签名、arm64 主程序和最低系统要求。公开分发建议补齐 Developer ID、公证及真实 Gatekeeper 测试；当前仍仅 ad-hoc。
3. 用 `ditto -c -k --keepParent` 将 `UsageTopbar.app` 打包为 `UsageTopbar-<版本>-macOS-arm64.zip`。最终包先执行：

   ```sh
   python3 scripts/sign-update.py <ZIP路径> --version <展示版本> --build <递增构建号>
   ```

   此默认命令只检查固定 Bundle ID、精确版本/build、公钥、更新源和安全配置。添加 `--sign` 才会调用官方 `sign_update` 使用钥匙串密钥签署该 ZIP，绝不导出私钥。

4. 把通过检查的最终 ZIP 放入专用发布目录。用固定官方工具生成并签署 feed：

   ```sh
   SPARKLE=$(scripts/fetch-sparkle.sh)
   "$SPARKLE/bin/generate_appcast" --account ALEXESLAT.usage-topbar \
     --maximum-deltas 0 \
     --download-url-prefix https://github.com/ALEXESLAT/usage-topbar/releases/download/v<版本>/ \
     <专用发布目录>
   ```

   该命令使用同一钥匙串密钥签署包和 appcast；不要传私钥参数，不把私钥放到环境变量或 CI。钥匙串如需授权，由维护者在本机处理，不改访问控制来绕过。签名后不能改写 XML 或包。

5. 测试签名 feed/包和安装失败场景。正式发布得到授权后，先上传并重新下载核验 Release ZIP，再提交对应签名的 `updates/appcast.xml`。feed 地址固定为 `https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml`。保留上一版已验证包以便显式恢复。
6. 从已安装的带更新器版本验证发现、下载、安装、重启及子进程退出。不能只验证下载页或 SHA-256 就宣布升级成功。

## 安全与隐私

强制签名 feed 和解压前验签，签名失败超时降级关闭。只接受固定项目 HTTPS 下载源及递增整数 build；Sparkle 负责签名真实性和安装。本项目签名前门槛补充精确包身份/版本检查。签名证明来源，不证明最新：历史有效 feed 仍可能冻结更新，或提供高于本机但非最新的版本。

自动检查/下载/安装、系统画像、远程发布说明和 JavaScript 均关闭。手动检查会向 GitHub/CDN发送普通连接和 HTTP 元数据，可能含客户端/系统版本；不附加账户、额度、卡信息或凭据。更新器不变更录屏权限、系统安全设置或已有登录项；不可写安装目录可能需要系统授权。

密钥丢失可能要求重新手动安装以建立信任，泄露可伪造更新。备份导出未获本轮授权，也未执行；未来须明确指定受保护的加密离线位置，不能导出到仓库或聊天。

## 已测与剩余限制

- 本机独立 Bundle ID、回环 HTTP 传输、真实签名 feed/ZIP及真实 Sparkle 安装器，共 15 类场景，13 类满足预期：21→22 替换重启、无新版、篡改 feed/包、拒绝降级包、检查/提示/下载/待安装阶段取消、feed/下载 404、下载中断、安装辅助程序缺失。失败/取消保持旧版；测试子进程均清理。
- 两项未满足：同一可信密钥签名的错误 Bundle ID，以及包实际版本 23 与 feed 22 不一致，均最终安装。签名前门槛已覆盖并拒绝这两类误包，但不声称 Sparkle 在运行时拒绝它们。
- 回环 HTTP 和可编程测试交互仅存在于独立测试宿主，未加入生产 URL 策略。没有测试公开 HTTPS/CDN链路、安装替换中途磁盘故障的事务回滚、真实 Codex 子进程升级重启或公证后的行为。
- 测试宿主使用自己创建的 sleep 子进程验证退出清理；这不等于真实 Codex 进程测试。原有应用回归另行通过。

官方资料：[接入](https://sparkle-project.org/documentation/programmatic-setup/) · [安全设置](https://sparkle-project.org/documentation/customization/) · [发布](https://sparkle-project.org/documentation/publishing/)

## 官方扩展点与威胁边界

已检查 Sparkle 2.10.0 公开 SPUUpdaterDelegate：shouldProceedWithUpdate 只提供下载前 feed 元数据；didExtractUpdate / willInstallUpdate 是通知，未提供提取后包路径或抛错拒绝返回值；延迟重启不是验证入口。未找到能可靠强制包 Bundle ID 和 feed 精确版本一致的受支持委托。不会猜测私有缓存路径、调用私有 API 或自行替换应用。

无私钥攻击者篡改 feed/ZIP 已被拒绝。两项未满足场景需要可信私钥签署错误内容；发布前门槛降低误签风险。私钥泄露意味着更新发布权失守，Bundle ID 检查也挡不住同 ID 的恶意代码。不能未经实测声称 Developer ID 自动补齐精确匹配要求。

若必须具备独立的运行时精确包身份/版本拒绝，最小保守替代是暂不交付一键替换，仅提供版本提醒和官方包下载入口，继续手动安装；本轮没有擅自切换方案。保留自动替换且强制该约束，需要上游支持或另行审查维护框架修改。正式发布保持暂停。

Pinned sources: [delegate](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SPUUpdaterDelegate.h), [bundle selection](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUInstaller.m), [actual downgrade prevention](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUPlainInstaller.m).

## 升级后保留设置

0.5.0 开始把用户手动显示/隐藏浮层的选择保存在固定偏好域 `local.alex.usage-topbar` 的 `overlay.userHidden`；首次安装或从无此设置的 0.4.0 升级时默认显示，不把自动避让隐藏误当成用户设置。演示模式不写入此偏好。窗口位置、配色及尺寸由布局和当前环境计算，不是可迁移的用户设置。后续升级保持 Bundle ID 和偏好键不变，无需复制设置进安装包。

登录项由 macOS ServiceManagement 保存，更新器不注册或注销；真实升级后的登录启动仍需专项实测。应用没有自己的账号配置或凭据存储，调用本机 Codex app-server 使用已有登录，升级不复制、读取或改写凭据。Sparkle 自身偏好位于同一应用域，启动时有意强制关闭自动检查、下载和系统画像。

客户端精确 Bundle ID/feed build 匹配属于额外约束，当前未强制，并非用户硬要求或无私钥攻击证据。保留上述误签限制与测试失败记录；可继续知情用户的 ad-hoc 内测，公开发行推荐 Developer ID、公证及真实下载验收。

设置专项隔离测试：以同一生产 OverlayPreferences 代码，在独立偏好域分别保存隐藏/显示与额外哨兵键，真实 Sparkle 21→22 替换重启后全部读回一致。初次及复跑共四次最终成功；早期脚本曾在安装终态前超时，原始记录保留，后续等待改为最长 180 秒并等新版退出。此测试通过独立宿主与设置探针完成，不等同于真实 AppDelegate 标准界面全流程测试。正式安装的版本、可执行文件、偏好文件存在性和登录项状态在前后只读核验一致。

## 真实候选标准界面验证

后续测试已使用真正的 AppDelegate、RateLimitClient、设置代码与 Sparkle 标准界面完成 21→22 下载、安装、重启；0.5.0→0.5.1 仅是隔离测试版本，不代表发布。副本只改动独立 Bundle ID/名称、回环更新源/下载策略和模拟 app-server 路径，生产代码没有这些测试例外。通过现有辅助功能授权操作真实菜单与按钮，没有自定义 Sparkle user driver。

已测启动不自动检查、检查取消、无新版、清单 404、错误签名、跳过版本、下载取消、包 404、安装并重启。新版实际恢复隐藏偏好，菜单切换写回相反值；实际 AppDelegate 在升级与正常退出时均清理模拟 app-server。安装器曾在文件替换调用等待数分钟，最终自行完成；以最终包、签名和新进程判定成功。正式安装与登录项前后未变。

这补充了前述独立宿主测试，但不等于真实凭据/OpenAI 请求、所有 UI 分支、登录/注销或重启 Mac 测试。公开 HTTPS/CDN、Developer ID/公证及带隔离属性的下载仍待验证；未上传任何远端测试 Release 或清单。
