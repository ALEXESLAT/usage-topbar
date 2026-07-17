# Usage Topbar

Usage Topbar is a compact native macOS overlay that keeps Codex usage visible in the ChatGPT title bar without covering the task title or the right-side controls.

![Usage Topbar preview](assets/usage-topbar-preview.png)

## Features

- Live remaining usage: reads the authenticated Codex rate-limit state every 30 seconds and displays the most constrained available window.
- Compact progress display: combines a color-coded progress bar, remaining percentage, window duration, points balance, and next reset time in one short bar.
- Liquid-glass appearance: uses the native macOS glass effect where available, with a polished visual-effect fallback on earlier supported systems.
- Adaptive readability: samples only the average brightness of a tiny 12 x 12 px title-bar region and automatically switches between dark and light text.
- Smart positioning: follows the main ChatGPT window, stays in the title bar, and reserves space for the task title and optional right sidebar.
- Status-bar controls: refresh immediately, show or hide the overlay, or quit from the macOS menu bar.
- Privacy-first operation: usage snapshots, window geometry, color samples, and screenshots are kept in memory and are not written to disk.

## 功能概览

Usage Topbar 是一款原生 macOS Codex 用量浮层。它会在 ChatGPT 顶栏中显示剩余百分比、周期、points 和重置时间，并通过液态玻璃、自适应明暗字体及智能位置避让，在保持信息可读的同时不遮挡标题和右侧按钮。

## Requirements

- Apple Silicon Mac
- macOS 13 or later
- ChatGPT/Codex desktop environment with an authenticated Codex app-server

## Install the macOS app

1. Download `UsageTopbar-0.2.0-macOS-arm64.zip` from the GitHub release.
2. Unzip it and move `UsageTopbar.app` to Applications.
3. Open the app and review the privacy disclosure before starting live mode.

The app is ad-hoc signed and not notarized. macOS may require you to approve the first launch from System Settings.

## Build

```sh
scripts/build-overlay.sh
```

The built app is written to `bin/UsageTopbar.app`.

## Controls

Use the menu-bar item to refresh, show or hide the overlay, or quit. Plugin management commands are available through:

```sh
skills/manage-usage-topbar/scripts/control.sh demo
skills/manage-usage-topbar/scripts/control.sh status
skills/manage-usage-topbar/scripts/control.sh build
```

Live start intentionally requires a per-launch privacy confirmation.

## Data and privacy

The app requests Codex rate-limit percentages, window durations, reset timestamps, and points balance from the local Codex app-server. It enumerates ChatGPT window geometry for positioning and, only when Screen Recording access is already available, calculates the average luminance of a 12 x 12 px title-bar sample. It performs no OCR and does not automatically request Screen Recording permission.

No third party receives window geometry or color samples. OpenAI receives the authenticated rate-limit read request. The app does not persist usage data, credentials, screenshots, or sampled colors.

## Version

Current release: `0.2.0`
