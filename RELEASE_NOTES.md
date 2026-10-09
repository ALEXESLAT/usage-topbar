# Usage Topbar 0.2.6

Usage Topbar 0.2.6 (build 17) publishes the accumulated 0.2.5 development improvements and subsequent reliability fixes.

> **AI-generated software:** This program and its documentation were written by artificial intelligence.
>
> **AI 生成声明：** 本程序及其文档由人工智能编写。

## Changes

- Reserve enough width for the complete `100%` label; separate whole-Mac throughput from the `CODEX` connection light.
- Drive connection status from the authenticated rate-limit request; remove generic TLS handshakes from live monitoring.
- Use a compact per-launch consent summary with optional details.
- Automatically restart the local Codex app-server after process failures, clear partial responses before reconnecting, and discover the current desktop app's bundled CLI location.
- Report unknown controller status when macOS denies process inspection.
- Recheck the frontmost Codex process and window ordering every positioning tick, correcting the overlay's position only when needed.
- Include the minimal usage-bars icon, native Liquid Glass treatment on macOS 26+, and macOS 13+ material fallback from 0.2.5.

## Packages

- `UsageTopbar-0.2.6-macOS-universal.dmg`: Apple Silicon and Intel app, Applications shortcut, and installation instructions.
- `UsageTopbar-0.2.6-macOS-arm64.zip`: Apple Silicon app.
- `usage-topbar-plugin-0.2.6.zip`: plugin and source.
- `SHA256SUMS.txt`: package checksums.

Applications use ad-hoc signatures and are not notarized. macOS 13 or later is required. No account data, credentials, logs, or usage snapshots are included.
