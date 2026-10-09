# Changelog

**English** · [简体中文](CHANGELOG.md)

The current public release is **[0.3.1 (19)](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.3.1)**. Historical platform support does not define current support.

## 0.3.1 (19) — 2026-10-09

- Apple Silicon (arm64) only, macOS 13 minimum.
- Unknown/failed usage displays `--%`; only Codex usage is selected, with duration and reset tied to its most constrained window.
- Initialization/read timeouts, matching responses, bounded retries, and sleep/wake recovery.
- Two-dimensional display positioning, scale and safe-area handling, with a menu-bar fallback when there is no room above the window.
- Actual elapsed sampling time and per-interface baselines reduce anomalies after interface changes, rollover, and sleep.
- Synthetic regression tests do not read real account data. See [release notes](RELEASE_NOTES.en.md) for validation limits.

This documentation update occurred after release. Packages were not rebuilt or replaced; their internal documentation remains the release-time snapshot.

## 0.3.0 (18) — retained historical tag; no release

The [source tag](https://github.com/ALEXESLAT/usage-topbar/tree/v0.3.0) was pushed before the platform scope changed and retains the dual-architecture build configuration from that point. The Apple Silicon-only release moved to 0.3.1 to preserve tag history. Download 0.3.1; the 0.3.0 tag does not represent a delivered installer release.

## 0.2.6 (17) — 2026-10-09

[Historical release](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.6): accumulated 0.2.5 development work plus connection and window-ordering fixes. It provided a universal DMG and an arm64 ZIP. Current 0.3.1 support is arm64 only.

## Earlier versions

- 0.2.5 (16): development-branch and local-delivery version, without a same-named GitHub release; its work was incorporated into later releases.
- [0.2.3](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.3): historical arm64 release improving attachment, foreground visibility, and ordering.
- [0.2.1](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.1) and [0.2.0](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.0): original notes and assets remain available for historical reference.
