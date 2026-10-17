# Usage Topbar

**English** · [简体中文](README.md)

> 0.6.26 has been withdrawn from stable distribution. History/color changes remain under review; the stable download is 0.5.0. Installed apps are not automatically downgraded.

A lightweight, liquid-glass-style companion for Apple Silicon Macs. Keep Codex remaining usage, its limiting window, reset countdown, points, and whole-Mac throughput at the window edge and in the menu bar.

See your remaining allowance at a glance while Codex is running, without clicking the avatar in the lower-left corner and opening a submenu to check it. Keeping this information in view can help ease anxiety about usage limits.

**Public release: 0.5.0 (build 24) · Apple Silicon (arm64) · macOS 13+**

[Download DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.dmg) · [Download ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.zip) · [Release](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.5.0) · [Installation and usage](docs/USAGE.en.md) · [Changelog](CHANGELOG.en.md) · [Report a problem](https://github.com/ALEXESLAT/usage-topbar/issues)

![Anonymous Usage Topbar demo](assets/previews/usage-topbar-0.4.0.png)

*Rendered with the actual 0.4.0 UI components, simulated data, and a static dark background; live Liquid Glass refraction is not shown.*

**0.6.26 adds local quota history**: a four-day overview, scrollable seven-day detail, reset events and three-month retention. History saves on a serial background queue; hidden history views skip data refreshes.

The history title bar blends into full-size content, retaining close controls and blank-area dragging. Testing history detail uses separate axis/point percentages and a bottom time label. The four-day popover uses one compact percentage and a locator dot; click to open seven-day detail. Local control and builds default to the isolated Testing app. Production requires explicit `USAGE_TOPBAR_CHANNEL=release` and is not replaced during testing iterations.

History readouts and Return to Now use native Liquid Glass on macOS 26+, compatible material on older systems, and solid surfaces with Reduce Transparency. History follows the effective theme at runtime. The plot itself has no glass overlay.

Testing menu → **Gradient settings** edits the main quota bar with movable color/alpha stops, preview, save/cancel and reset. The full-track gradient stays fixed as quota clips from the right. History uses full background blur and adaptive tint to keep background text from competing with the chart.

## Features

- Codex remaining usage, limiting window, reset countdown, and points.
- An overlay following the foreground Codex/ChatGPT window, with menu-bar refresh, visibility, and quit controls.
- Whole-Mac upload/download rates. Unknown usage shows `--%`; a valid zero shows `0%`.
- Native Liquid Glass on macOS 26+, with SwiftUI material on earlier systems.

## Get started

1. Use an Apple Silicon Mac (macOS 13+) with a signed-in Codex/ChatGPT desktop app providing app-server.
2. Download the DMG and drag the app to Applications. Quit the previous version before updating.
3. Open the app to start monitoring the documented data immediately, without an extra launch confirmation or API key entry.

This release is **ad-hoc signed and not notarized by Apple**. macOS may block the first launch; see [installation, checksums, and troubleshooting](docs/USAGE.en.md). Intel Macs are unsupported.

## Updates and settings

- Install 0.5.0 manually once if upgrading from 0.4.0, then use “Check for Updates…”.
- Updates use the signed production feed and verified downloads, with user-confirmed installation and relaunch. No automatic checks, downloads or installation, forced restart, or system profiling.
- Explicit overlay visibility is saved; existing login-item state is preserved.

Automatic health rollback is not implemented. See the [update guide](docs/UPDATES.en.md) for the update flow, release validation and recovery limits.

## More

[Usage and privacy](docs/USAGE.en.md) · [Development and contributions](CONTRIBUTING.en.md) · [Release notes](RELEASE_NOTES.en.md) · [Automated checks](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml)

Usage is read from OpenAI through the local Codex app-server. Interface statistics and window handling stay on the Mac. Version 0.6.0 stores quota history and one-way account/card ID digests locally for three months, never credentials; see the guide for the complete data scope.

Local mock regressions, builds, and renders have been checked. Older systems, physical multi-display/notch setups, and prolonged real-account use remain untested on devices. Licensed under the [MIT License](LICENSE). Copyright © 2026 ALEXESLAT.

> The software and documentation were written by artificial intelligence.
