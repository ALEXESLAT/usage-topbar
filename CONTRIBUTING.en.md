# Development and contributions

**English** · [简体中文](CONTRIBUTING.md)

## Build from source

The default branch `main` now contains the 0.4.0 release source and current documentation. **Check out the `v0.4.0` tag to reproduce this exact release.**

Use an Apple Silicon Mac and an Xcode/Swift toolchain with the macOS 26 SDK or newer. Regression tests additionally require Python 3. The app's deployment target remains macOS 13+.

```sh
git clone --branch v0.4.0 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

The arm64 app is written to `${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app`. Building does not install it. Source, management skills, and tests are also included in the [plugin package](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/usage-topbar-plugin-0.4.0.zip). Package documentation remains the release-time snapshot; this repository carries the updated guides.

## Propose a change

Check existing issues first. Include reproduction steps and relevant regression results for behavior changes, and anonymous demo images for UI changes. Keep arm64, the macOS 13 deployment target, and material fallbacks for older systems. Update both language sets. Never commit credentials, real usage, logs, or local build directories.

CI runs mock regressions, builds, architecture/signature checks, and UI renders and startup regressions on a standard macOS 26 arm64 runner. Check artifacts last 7 days and are not official releases. See [Actions](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml). This does not validate older systems, physical display setups, or prolonged real-account use.

## Releases and license

Use [Releases](https://github.com/ALEXESLAT/usage-topbar/releases) for official builds. Before publishing, check version/build numbers, tests, arm64 architecture, signature, checksums, and attachments. CI does not publish releases.

Licensed under the [MIT License](LICENSE). Copyright © 2026 ALEXESLAT. Preserve the copyright and license notices when using, modifying, or distributing the software. Third-party content retains its original terms.

[Usage guide](docs/USAGE.en.md) · [Home](README.en.md)
