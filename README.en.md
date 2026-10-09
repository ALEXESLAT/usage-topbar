# Usage Topbar

**English** · [简体中文](README.md)

A lightweight, liquid-glass-style companion for Apple Silicon Macs. Keep Codex remaining usage, its limiting window, reset countdown, points, and whole-Mac throughput at the window edge and in the menu bar.

**Current version: 0.3.1 (build 19) · Apple Silicon (arm64) · macOS 13+**

[Download DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.dmg) · [Download ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.zip) · [Release](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.3.1) · [Installation and usage](docs/USAGE.en.md) · [Changelog](CHANGELOG.en.md)

![Interface illustration using generated demo data](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-preview.png)

> The software and documentation were written by artificial intelligence.

## What it does

- Reads authenticated Codex usage about every 30 seconds and shows the most constrained available Codex window, its remaining percentage, duration, and matching reset time.
- Attaches above the upper-left edge of the foreground Codex/ChatGPT window and stays behind that window. It hides when another app is active or when there is insufficient space above the window; the menu-bar indicator remains available.
- Separates the `CODEX` request-status light from whole-Mac upload/download rates. These rates are not Codex-only traffic.
- Provides menu-bar refresh, overlay visibility, and quit controls. Monitoring pauses on sleep and reconnects after wake.
- Uses native Liquid Glass on macOS 26+ and SwiftUI material on earlier supported systems. Placement accounts for display position, scale, and safe areas.

## Install

1. Use an Apple Silicon (M-series) Mac running macOS 13 or later, with an installed and signed-in Codex/ChatGPT desktop application providing a usable app-server. **Intel Macs are not supported.**
2. Download the DMG and drag `UsageTopbar.app` to Applications. Alternatively, extract the ZIP and move the app to `/Applications`.
3. Open the app, review the data disclosure, and choose Start to allow live reading for this launch. Cancel exits the app. You do not enter account credentials into Usage Topbar.

The app is **ad-hoc signed and not notarized by Apple**. If macOS blocks the first launch, verify the download source and follow the system's per-app opening prompts. Do not disable Gatekeeper or weaken global security settings.

Compare downloaded files with [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/SHA256SUMS.txt). Quit the old instance before replacing the application when updating.

## Read the display

| Display | Meaning |
| --- | --- |
| `0%`–`100%` | Remaining usage from the latest valid read, for the most constrained available Codex window |
| `--%` | Initializing, offline, a failed request, or unavailable data; it does not mean the allowance is exhausted |
| `points --` | No valid points balance was returned |
| Green / yellow / red | Successful usage request / checking / failed request or unavailable local network; not a general internet speed test |
| `↓` / `↑` | Approximate throughput from the Mac's selected external interfaces; sampled about every 2 seconds on external power, or 5 seconds on battery/Low Power Mode |

A normal refresh retains the latest valid value; a detected failure changes it to `--%`. Usage is not updated every second and does not guarantee that a particular model request will succeed. See the [usage guide](docs/USAGE.en.md) for controls, troubleshooting, and privacy details.

## Build from source

The default branch `main` now contains the 0.3.1 release source and current documentation. **Check out the `v0.3.1` tag to reproduce this exact release.**

Use an Apple Silicon Mac and an Xcode/Swift toolchain with the macOS 26 SDK or newer. Regression tests additionally require Python 3. The app's deployment target remains macOS 13+.

```sh
git clone --branch v0.3.1 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

The arm64 app is written to `${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app`. Building does not install it. Source, management skills, and tests are also included in the [plugin package](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-plugin-0.3.1.zip). Package documentation remains the release-time snapshot; this repository carries the updated guides.

## Data and validation

Usage Topbar reads usage from OpenAI through the local Codex app-server. It calculates interface-counter deltas and window placement locally. On macOS 14+ with existing Screen Recording permission, it samples average luminance from a 12×12-point title-bar region at most about every 3 seconds. Otherwise it uses system appearance. It does not request this permission automatically or perform OCR.

Usage Topbar itself does not persist usage snapshots, credentials, throughput statistics, window geometry, screenshots, or color samples. OpenAI receives usage requests and normal connection metadata. Codex's own storage and account behavior are governed by its settings.

Native builds, synthetic regressions, and UI rendering were checked on Apple Silicon / macOS 27.2: 17 quota, 8 geometry, and 4 throughput assertions plus 7 mock-service lifecycle scenarios passed. Twelve light/dark, scale, and value-state renders passed. Package architecture, version, signature, and checksums were verified.

**Older supported macOS installations, physical multi-monitor/notch configurations, and prolonged monitoring of a real account have not been tested on devices.** This repository has no GitHub Actions workflow; no CI pass is claimed. Signing and deployment-target declarations do not establish compatibility with every Mac.
