# 开发与贡献

**简体中文** · [English](CONTRIBUTING.en.md)

## 从源码构建

默认分支 `main` 已同步 0.3.1 发布源码及最新文档。**若要精确复现本次发布，请检出 `v0.3.1` 标签。**

需要 Apple Silicon Mac、含 macOS 26 或更新 SDK 的 Xcode/Swift 工具链；回归测试还需要 Python 3。编译目标仍为 macOS 13+。

```sh
git clone --branch v0.3.1 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

构建产物位于 `${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app`，仅包含 arm64；构建不会自动安装。源码、管理技能和测试也包含在 [插件包](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-plugin-0.3.1.zip) 中。已发布包内文档保持发布时快照，最新说明以本仓库文档为准。

## 提交改动

先查找已有 Issue；行为改动请附复现步骤、相关回归结果，界面改动使用匿名演示图。保持 arm64、macOS 13 部署目标和较旧系统的材质降级。同步更新中英文文档。不要提交凭据、真实用量、日志或本机构建目录。

CI 在标准 macOS 26 arm64 runner 上运行模拟回归、构建、架构/签名检查和 12 种渲染；产物仅供检查，保留 7 天，不是正式发布。运行记录见 [Actions](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml)。它不证明旧系统、物理多屏或真实账户长时间运行已验证。

## 发布与许可

正式版本以 [Releases](https://github.com/ALEXESLAT/usage-topbar/releases) 为准。发布前核对版本/构建号、测试、arm64、签名与校验和，并人工确认附件；CI 不创建发布。

仓库尚未指定许可证；公开可见不代表已授予开源使用许可。涉及复用、分发或贡献授权，请先与维护者确认。

[使用指南](docs/USAGE.md) · [返回主页](README.md)
