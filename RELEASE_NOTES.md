# Usage Topbar 0.3.0

Version 0.3.0 (build 18) improves Mac compatibility and usage-data correctness while preserving the compact edge-tab design.

> **AI-generated software:** This program and its documentation were written by artificial intelligence.
>
> **AI 生成声明：** 本程序及其文档由人工智能编写。

## Changes

- Build universal arm64/x86_64 applications by default, targeting macOS 13+. Retain gated macOS 26 Liquid Glass and earlier-system material fallback.
- Place the overlay using both display axes, Retina scale, visible bounds, and notch safe area. Clamp horizontal edges; hide the overlay when no space remains above Codex, keeping the compact menu-bar indicator available. Track the frontmost matching window, including narrower windows.
- Show unavailable usage as `--%`; never substitute another model's quota for Codex. Display the actual limiting window duration and its matching reset, validate numeric data, and reject stale/unmatched responses.
- Recover from initialization/read timeouts and process failures with bounded buffers and capped backoff. Suspend monitoring on sleep and reconnect on wake. Discover bundled CLIs in registered Codex/ChatGPT application locations.
- Calculate throughput from real elapsed time and per-interface counters, preventing sleep, rollover, and interface-switch spikes. Add timer tolerance and reduce contrast sampling frequency.
- Add credential-free parser, display geometry, throughput, and mock app-server regression tests.

## Packages

- `UsageTopbar-0.3.0-macOS-universal.dmg`: Apple Silicon and Intel app, Applications shortcut, installation instructions.
- `UsageTopbar-0.3.0-macOS-arm64.zip`: Apple Silicon app.
- `usage-topbar-plugin-0.3.0.zip`: plugin, source, and synthetic regression tests.
- `SHA256SUMS.txt`: artifact checksums.

## Validation

- Native arm64 and Rosetta x86_64 regression suites passed: 17 quota assertions, 8 geometry assertions, 4 throughput assertions, and 7 mock app-server lifecycle scenarios per architecture.
- Both executable slices declare macOS 13.0 minimum deployment; ad-hoc signature verification passed.
- Native and Rosetta preview rendering passed; 12 light/dark, 1x/2x, full/zero/unavailable UI variants rendered successfully.
- Host: Apple Silicon, macOS 27.2. No repository GitHub Actions workflow is configured.

## Verification limits

The app is ad-hoc signed, not Developer ID signed or notarized. No installation or security settings are changed by this release task. Real Intel hardware, older macOS installations, physical multi-monitor/notch combinations, and authenticated live account monitoring require additional device testing; simulated geometry and universal builds do not replace those checks.
