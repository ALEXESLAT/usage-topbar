# Usage Topbar

**English** · [简体中文](README.md)

A lightweight, liquid-glass-style companion for Apple Silicon Macs. Keep Codex remaining usage, its limiting window, reset countdown, points, and whole-Mac throughput at the window edge and in the menu bar.

**Current version: 0.3.1 (build 19) · Apple Silicon (arm64) · macOS 13+**

[Download DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.dmg) · [Download ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.zip) · [Release](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.3.1) · [Installation and usage](docs/USAGE.en.md) · [Changelog](CHANGELOG.en.md) · [Report a problem](https://github.com/ALEXESLAT/usage-topbar/issues)

![Anonymous Usage Topbar demo](assets/previews/usage-topbar-0.3.1.png)

*Rendered with the actual 0.3.1 UI components, simulated data, and a static dark background; live Liquid Glass refraction is not shown.*

## Features

- Codex remaining usage, limiting window, reset countdown, and points.
- An overlay following the foreground Codex/ChatGPT window, with menu-bar refresh, visibility, and quit controls.
- Whole-Mac upload/download rates. Unknown usage shows `--%`; a valid zero shows `0%`.
- Native Liquid Glass on macOS 26+, with SwiftUI material on earlier systems.

## Get started

1. Use an Apple Silicon Mac (macOS 13+) with a signed-in Codex/ChatGPT desktop app providing app-server.
2. Download the DMG and drag the app to Applications. Quit the previous version before updating.
3. Open the app, read the data disclosure, and choose Start. No API key entry is required.

This release is **ad-hoc signed and not notarized by Apple**. macOS may block the first launch; see [installation, checksums, and troubleshooting](docs/USAGE.en.md). Intel Macs are unsupported.

## More

[Usage and privacy](docs/USAGE.en.md) · [Development and contributions](CONTRIBUTING.en.md) · [Release notes](RELEASE_NOTES.en.md) · [Automated checks](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml)

Usage is read from OpenAI through the local Codex app-server. Interface statistics and window handling stay on the Mac. The app itself does not store usage or credentials; see the guide for the complete data scope.

Local mock regressions, builds, and renders have been checked. Older systems, physical multi-display/notch setups, and prolonged real-account use remain untested on devices. Licensed under the [MIT License](LICENSE). Copyright © 2026 ALEXESLAT.

> The software and documentation were written by artificial intelligence.
