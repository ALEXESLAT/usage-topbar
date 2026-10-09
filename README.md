# Usage Topbar

Usage Topbar is a compact native macOS edge tab that keeps Codex usage visible immediately above the window's traffic-light controls without covering the window itself.

> **AI-generated software:** This program and its documentation were written by artificial intelligence.
>
> **AI 生成声明：** 本程序及其文档由人工智能编写。

![Usage Topbar preview](assets/usage-topbar-preview.png)

## Features

- Live remaining usage: reads the authenticated Codex rate-limit state every 30 seconds and displays the most constrained available window.
- Codex connectivity indicator: green means the authenticated Codex rate-limit request succeeded, yellow means it is checking, and red means that request failed or the local network path is unavailable. Generic internet reachability does not override this state.
- Low-overhead system throughput: reads cumulative byte counters from active external network interfaces and shows compact download/upload rates beneath the separate `CODEX` status. Sampling adapts from two seconds on external power to five seconds on battery or in Low Power Mode, without inspecting destinations or traffic contents.
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

- Apple Silicon or Intel Mac (universal DMG; the ZIP is Apple Silicon only)
- macOS 13 or later
- ChatGPT/Codex desktop environment with an authenticated Codex app-server

## Install the macOS app

1. Download `UsageTopbar-0.2.6-macOS-universal.dmg` from the release package.
2. Open it and drag `UsageTopbar.app` to Applications.
3. Open the app and review the privacy disclosure before starting live mode.

The app is ad-hoc signed and not notarized. macOS may require you to approve the first launch from System Settings.

## Build

```sh
scripts/usage-topbar.sh build
```

The built app is written to `${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app`.
This keeps temporary development bundles outside the project so Spotlight does
not show duplicate installable copies. The canonical runnable copy belongs only
at `/Applications/UsageTopbar.app`.

## Controls

Use the menu-bar item to refresh, show or hide the overlay, or quit. Plugin management commands are available through:

```sh
skills/manage-usage-topbar/scripts/control.sh demo
skills/manage-usage-topbar/scripts/control.sh status
skills/manage-usage-topbar/scripts/control.sh build
```

Live start intentionally requires a per-launch privacy confirmation.

## Data and privacy

The app requests Codex rate-limit percentages, window durations, reset timestamps, and points balance from the local Codex app-server every 30 seconds. The result of that authenticated request drives the Codex connection indicator. It locally reads cumulative byte counters from active external network interfaces every two seconds on external power or every five seconds on battery/Low Power Mode to display whole-Mac throughput. It enumerates ChatGPT window geometry for positioning and, only when Screen Recording access is already available, calculates the average luminance of a 12 x 12 px title-bar sample. It reads no traffic contents, performs no OCR, and does not automatically request Screen Recording permission.

No third party receives interface statistics, window geometry, or color samples. OpenAI receives the authenticated rate-limit read request and its normal connection metadata. The app does not persist usage data, connection results, network statistics, credentials, screenshots, or sampled colors.

## Version

Current release: `0.2.6` (build 17)
