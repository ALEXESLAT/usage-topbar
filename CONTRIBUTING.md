# 开发与贡献

**简体中文** · [English](CONTRIBUTING.en.md)

## 从源码构建

默认分支 `main` 已同步 0.5.0 发布源码及最新文档。**若要精确复现本次发布，请检出 `v0.5.0` 标签。**

需要 Apple Silicon Mac、含 macOS 26 或更新 SDK 的 Xcode/Swift 工具链；回归测试还需要 Python 3。编译目标仍为 macOS 13+。

```sh
git clone --branch v0.5.0 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

构建产物位于 `${TMPDIR:-/private/tmp}/usage-topbar-testing/UsageTopbar Testing.app`，仅包含 arm64；构建不会自动安装。源码、管理技能和测试也包含在 [插件包](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/usage-topbar-plugin-0.5.0.zip) 中。已发布包内文档保持发布时快照，最新说明以本仓库文档为准。

## 提交改动

先查找已有 Issue；行为改动请附复现步骤、相关回归结果，界面改动使用匿名演示图。保持 arm64、macOS 13 部署目标和较旧系统的材质降级。同步更新中英文文档。不要提交凭据、真实用量、日志或本机构建目录。

CI 在标准 macOS 26 arm64 runner 上运行模拟回归、构建、架构/签名检查和 界面渲染及启动回归；产物仅供检查，保留 7 天，不是正式发布。运行记录见 [Actions](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml)。它不证明旧系统、物理多屏或真实账户长时间运行已验证。

## 发布与许可

正式版本以 [Releases](https://github.com/ALEXESLAT/usage-topbar/releases) 为准。发布前核对版本/构建号、测试、arm64、签名与校验和，并人工确认附件；CI 不创建发布。

采用 [MIT 许可证](LICENSE)，版权署名 © 2026 ALEXESLAT。使用、修改或分发时须保留版权和许可声明；第三方内容仍遵循其原有许可。

[使用指南](docs/USAGE.md) · [返回主页](README.md)

## 更新器维护

构建现在需要 Python 3 和 HTTPS 访问 GitHub 来取得固定 Sparkle 2.10.0；缓存可由 `USAGE_TOPBAR_DEPENDENCY_CACHE` 指定。`python3 tests/run-updater.py` 不生成密钥。框架及外部组件许可随 app 保留。密钥与发布边界见[更新开发说明](docs/UPDATES.md)。

## 持续迭代与历史图数据源

为已知的后续开发方向预留轻量接口，在不影响主体功能和性能的前提下做好准备；避免围绕假想功能过度设计。采集、持久化和展示分离，数据格式保持显式版本，升级时考虑旧数据兼容；不为扩展点新增后台轮询。

历史图通过只读 `HistoryDataSource` 获取数据。真实 `QuotaHistoryStore` 继续负责采集结果与 v1 文件；测试模拟源仅在内存中生成，不进入存储或实时额度链路。模拟源以启动时最近半小时为锚点生成确定的 14 天数据，覆盖平台、下降、短缺测、长断档及三类重置。打开图表不会重新生成随机数据。

0.6.5 测试版默认模拟历史，图上标注“模拟数据”。退出测试版后执行 `defaults write local.alex.usage-topbar.testing history.useSimulatedData -bool false`，再启动即可使用真实历史；改为 `true` 或删除该键恢复模拟。此切换不更改历史文件。正式 release 编译排除模拟源且忽略此偏好，构建强制 `UsageTopbarHistorySource=real`，发布签名前校验拒绝模拟或缺失标记。发布仍需检查实际 release 二进制 `--variant-info` 的 `historySource` 为 `real`。

### 正式升级的真实历史接续（0.6.6）

测试版与正式版分别使用 `Application Support/UsageTopbar Testing/history-v1.json` 和 `Application Support/UsageTopbar/history-v1.json`，偏好域独立。常规 app 替换不删除外部历史文件或原正式偏好；三个月保留规则仍适用。

`HistoryMigration` 在正式版正常启动、打开默认历史库时自动合并测试版的原子文件快照，无需用户手动搬文件。测试构建不自动执行，`--variant-info` 不触发迁移。只在启动时执行，不新增轮询；测试版继续采样不会修改已读取的快照，后续正式启动可补入新增记录。

导入校验 v1、数值、账户/卡片摘要、周期与重置证据来源，拒绝模拟标识、模拟来源及未知版本，排除过期和未来记录。按账户摘要、周期、时间戳去重；同键冲突保留正式记录，新增来源重复保留首条。无新增时不写盘、不创建备份。正式原记录保留，由正常存储继续应用三个月规则。

有新增时先在正式历史目录的 `migration-backups/<UUID>/` 保存源快照、原正式文件（若存在）及不含账户标识的数量/冲突报告；私有文件权限 0600。确认目标未变后原子写入，重读校验，失败恢复原文件（原本不存在则移除新文件）。源文件始终不改；备份供手动回退，且不会覆盖正式偏好。错误在真实历史图显示，修复后重启可重试。

本轮只在临时隔离目录及真实历史的本地快照演练，未写当前正式目录、未安装正式构建、未发布。发布前运行 `python3 tests/run-migration.py`，并可将测试历史路径作为参数做只读快照演练，确认数量、时间范围和全部样本相同。流程保持：用户先测试，再授权 GitHub 发布，最后用户自行热更新；更新后的首次正式启动自动接续，账户匹配后显示对应历史。


### 0.6.25 历史图渲染与验收

主线6pt、50%平滑、末尾8个采样间隔局部重拟合、2h长缺失阈值、4天缩略/7天详情、4.5%重置条带保持。真实样本不改，十字线使用同一可见曲线缓存。日期轴使用独立绘制层，隔离NSClipView滚动像素复制，消除原生窗口中复现的叠字。

详情显示左轴百分比、交点百分比和底部坐标时间三个独立标签；缺失区只显示时间，重置不插中间值，移出清除。四天预览仅显示单个百分比标签和定位点，不挤占日期与轴栏，点击进入详情。循环箭头使用连续圆弧和圆角实心头部，卡片右下留空，特殊重置为环内饱满实心四角星，保持收小后的尺寸。

0.6.10已在解锁后的原生窗口验证自动注入HID左右滚动、惯性与两端回弹，日期无叠字；百分比、缺失及移出截图已保留。输入逐帧校验测试进程前台，这不等同物理触控板手势验收。四天预览按实际尺寸渲染检查，详情有实屏截图。测试专用 --exercise-history-scroll 只启动有限时轨迹记录，无常驻监听。


渐变验证：`python3 tests/run-gradient.py` 检查草稿、预览、保存/取消、格式和独立偏好域；`python3 tests/run.py --gradient` 以渲染像素比较 25/75/100% 的固定轨道颜色及右侧裁切。渐变编辑器仅测试版提供，正式版不读取测试配置。

### 迭代验证与前台操作

连续反馈合并为一个批次，优先后台构建、单测和受影响回归，通过后再安装一次 Testing，避免每次微调重启。沿用仍有效的证据，优先离屏渲染，不重复全状态截图。

实屏只检查受影响控件，使用最少截图。任何移动用户鼠标、键盘输入、切换前台或主题的操作，必须先说明并等待本次明确同意；此前验收授权不自动延续。当前前台自动验收暂停，直到用户新许可。未测项明确列出，不能写通过。

只清理本次确认可再生成的临时构建与冗余截图；保留源码、真实历史、用户文件、最终交付、必要回退和验证证据。
