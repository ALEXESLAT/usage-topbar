# Usage Topbar 0.3.1

**English** · [简体中文](RELEASE_NOTES.md)

**0.3.1 (build 19) · Apple Silicon (arm64) · macOS 13+**

A liquid-glass-style native macOS companion that places Codex remaining usage, its window, reset countdown, points, and whole-Mac throughput above the window's upper-left edge. The 0.3 series focuses on usage semantics, connection recovery, and display placement. This release supports Apple Silicon only, not Intel Macs.

## Download and install

- [arm64 DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.dmg): app, Applications shortcut, and installation instructions.
- [arm64 ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/UsageTopbar-0.3.1-macOS-arm64.zip): the same application in a ZIP archive.
- [Plugin and source](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/usage-topbar-plugin-0.3.1.zip): management skill, source, and synthetic regression tests.
- [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.3.1/SHA256SUMS.txt): download checksums.

Move `UsageTopbar.app` to `/Applications`; quit the old instance first when updating. The installed, signed-in Codex/ChatGPT environment must provide a usable app-server. Review and confirm the data disclosure before each live launch.

The app is **ad-hoc signed and not notarized by Apple**. macOS may block its first launch. Verify the source and follow per-app opening prompts; do not disable Gatekeeper or weaken global security settings.

[Complete usage guide](https://github.com/ALEXESLAT/usage-topbar/blob/main/docs/USAGE.en.md) · [Project overview](https://github.com/ALEXESLAT/usage-topbar/blob/main/README.en.md) · [Changelog](https://github.com/ALEXESLAT/usage-topbar/blob/main/CHANGELOG.en.md)

## Improvements

- **Clearer values:** unknown, offline, and failed reads show `--%`, not `0%`. Other models' buckets cannot replace Codex usage. Duration and countdown match the most constrained window.
- **Reliable recovery:** initialization/read deadlines, retries after failures and process exits, matching response IDs, bounded response buffers, sleep suspension, and fresh reads after wake.
- **Safer placement:** two-dimensional display positioning, scale and safe-area handling, narrower windows, and horizontal-edge constraints. When there is no space above Codex, the overlay hides and usage remains available in the menu bar.
- **Better throughput accounting:** actual sampling intervals and per-interface baselines avoid spikes after interface changes, rollover, or sleep. These are whole-Mac rates, not Codex-only traffic.
- **Familiar appearance:** native Liquid Glass on macOS 26+, SwiftUI material on earlier supported systems. Tiny-region luminance sampling requires macOS 14+ and existing permission; otherwise system appearance is used.

## Validation and limits

Checked on Apple Silicon / macOS 27.2:

- Native arm64 build and regressions: 17 quota, 8 geometry, and 4 throughput assertions, plus 7 mock-service lifecycle scenarios.
- Twelve light/dark, 1×/2×, full/zero/unknown UI renders.
- Packaged version 0.3.1 (19), arm64-only architecture, macOS 13.0 deployment target, ad-hoc signature, and DMG checksum. Published asset SHA-256 digests matched the local files.

**Older supported macOS installations, physical multi-monitor/notch combinations, and prolonged real-account monitoring have not been tested on devices.** Geometry simulation and successful compilation are not a guarantee for every Mac. See [GitHub Actions](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml) for subsequent repository checks; these are not retroactive CI validation of this release.

Usage Topbar itself does not save usage snapshots, credentials, throughput statistics, or screenshots. OpenAI receives usage requests and normal connection metadata. See the usage guide for the full data scope.

This update adds bilingual documentation and descriptions and brings the released source into `main`. Program logic, the `v0.3.1` tag, and binary assets retain their release-time contents. Documentation inside published packages is that original snapshot; current guides are in this repository.

> The software and documentation were written by artificial intelligence.
