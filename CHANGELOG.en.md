# Changelog

**English** · [简体中文](CHANGELOG.md)

The current public release is **[0.5.0 (24)](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.5.0)**. Historical platform support does not define current support.

## 0.5.0 (24) — 2026-10-09

- Adds “Check for Updates…” through Sparkle 2.10.0: a signed production feed, verified downloads, and user-confirmed installation/relaunch.
- No automatic checks, downloads or installation, forced restart, or system profiling.
- Persists explicit overlay visibility across relaunches and updates; existing login-item state is preserved.
- Frozen-snapshot signing, exact package identity/version checks, and final ZIP/feed/digest verification before and after publication.

## 0.4.0 (20) — 2026-10-09

- Compact overlay with a centered percentage, pts aligned to its actual left edge, card details above throughput, and a Codex menu-bar mark.
- Countdown follows the actual reset deadline; available reset-card count and earliest expiry use `Exp. MM/dd`, with `--` for unavailable details.
- Initial reads and recovery animate digits and bar together from zero to the actual value over about 0.8 seconds with ease-out. Routine refreshes do not replay it; reduced motion is respected.
- Monitoring starts directly within the disclosed scope, without a per-launch dialog. Optional launch at login defaults off for new users and preserves existing system registration.
- Background and manually hidden tracking checks fall back to one second; foreground and automatic hiding retain 0.2-second checks with immediate event handling. Presentation deduplication and font measurement caching avoid repeated work.

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
