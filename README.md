# Usage Topbar

Usage Topbar is a compact native macOS edge tab that keeps Codex usage visible immediately above the window's traffic-light controls without covering the window itself.

> **AI-generated software:** This program and its documentation were written by artificial intelligence.
>
> **AI 生成声明：** 本程序及其文档由人工智能编写。

![Usage Topbar preview](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.2.3/usage-topbar-preview.png)

## Features

- Live remaining usage: reads the authenticated Codex rate-limit state every 30 seconds and displays the most constrained available window.
- Compact progress display: combines a color-coded progress bar, remaining percentage, window duration, points balance, and next reset time in a two-line layout that does not truncate the reset countdown.
- SwiftUI liquid-glass appearance: uses SwiftUI's official `glassEffect(.regular)` on macOS 26 and a SwiftUI material fallback on earlier supported systems.
- Adaptive readability: samples only the average brightness of a tiny 12 x 12 px title-bar region and automatically switches between dark and light text.
- Window-attached positioning: follows the main Codex/ChatGPT window, places its 52 pt information area above the upper-left edge, and extends a rounded section 22 pt behind the window so the attachment remains seamless through the window corner.
- Codex-aware visibility and stacking: appears only while Codex is in the foreground and is ordered directly below the tracked Codex window instead of covering it or other apps.
- Status-bar controls: refresh immediately, show or hide the overlay, or quit from the macOS menu bar.
- Privacy-first operation: usage snapshots, window geometry, color samples, and screenshots are kept in memory and are not written to disk.

## 功能概览

Usage Topbar 是一款原生 macOS Codex 用量浮层。它吸附在 Codex 窗口左上边缘，在红黄绿信号灯上方显示剩余百分比、周期、points 和重置时间；下方 22 pt 隐藏在 Codex 窗口后面，并且仅在 Codex 位于前台时显示。

## Requirements

- Apple Silicon Mac
- macOS 13 or later
- ChatGPT/Codex desktop environment with an authenticated Codex app-server

## Install the macOS app

1. Download `UsageTopbar-0.2.3-macOS-arm64.zip` from the GitHub release.
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

Current release: `0.2.3` (build 13)
