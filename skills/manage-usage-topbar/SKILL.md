---
name: manage-usage-topbar
description: Start, stop, preview, rebuild, or inspect the local Usage Topbar macOS overlay. Use when the user asks to show live Codex remaining usage, open the usage bar, run a safe demo, check its status, or manage the usage-topbar companion app.
---

# Manage Usage Topbar

Use the deterministic controller at `scripts/control.sh`. The public release is 0.6.26 (51), for Apple Silicon / macOS 13+. See [installation and usage](../../docs/USAGE.md).

## Authorized monitoring scope

The user explicitly authorized direct startup for the following disclosed scope. Opening the app starts it without a repeated confirmation. Do not request the same authorization again; obtain new authorization before expanding this scope:

- Data: Codex rate-limit percentages, reset times, credit balance and reset-card count/expiry details, cumulative upload/download byte counts from the Mac's active external interfaces, ChatGPT window bounds, the average luminance of a 12×12 point title-bar sample, and the public IP, connection time, plus standard connection metadata produced by authenticated OpenAI usage requests.
- Purpose: render and position the local usage overlay, display whole-Mac live throughput and Codex connectivity, then select readable light or dark text.
- Operation: poll the local Codex app-server with `account/rateLimits/read` every 30 seconds; use the authenticated request result to drive connection status; locally calculate interface byte deltas every two/five seconds; enumerate Codex/ChatGPT window geometry for positioning; and use ScreenCaptureKit locally to sample a tiny color region without recognizing text or reading network contents.
- Recipient/service: OpenAI receives the authenticated rate-limit read and normal connection metadata; no third party receives data, and interface statistics, window geometry, plus color samples stay on the Mac.

The release intentionally has no per-launch dialog. It adds no login item automatically or credentials; quitting stops monitoring and terminates its own app-server child. Never trigger a macOS Screen Recording permission prompt automatically: sample colors only when permission is already available, otherwise silently fall back to the system appearance. `demo`, `preview`, `status`, `stop`, and `build` do not read account usage, interface statistics, window geometry, or screen colors.

## Local quota history (0.6.0)

The requested history feature reuses fresh rate-limit responses and locally stores timestamped remaining percentages, period/reset metadata and one-way account/card ID digests with card status/expiry evidence for three calendar months. Missing account IDs disable recording. No credentials, raw identifiers, emails or tokens are stored. Left click opens four days, a chart click opens the seven-day window, and right click retains settings. See `docs/USAGE.md` and the data contract for classification and privacy limits.

## Commands

Run from this skill directory:

```bash
scripts/control.sh start
scripts/control.sh demo
scripts/control.sh status
scripts/control.sh stop
scripts/control.sh build
scripts/control.sh preview
```

Prefer `demo` for validation because it uses generated sample percentages. `preview` prints the path to the existing repository screenshot; it does not regenerate it. `build` creates a temporary development app and does not install it. `start` and `demo` default to `/Applications/UsageTopbar Testing.app`, running the installed independent testing version. Only explicit `USAGE_TOPBAR_CHANNEL=release` targets `/Applications/UsageTopbar.app`.

If `start` reports a missing installed app, follow the installation guide; rebuilding alone will not install it. For other failures, inspect `status` and report the exact error without treating an inspection failure as stopped. `stop` defaults to processes named `UsageTopbarTest`; only explicit release channel targets `UsageTopbar`. Prefer the individual instance menu when closing only a demo. Do not patch or replace the Codex/ChatGPT desktop app.

Launch at login is an optional menu setting, off by default. Only a user click registers or unregisters SMAppService.mainApp. Read the actual service status; do not enable it or approve system prompts on the user’s behalf.

## Manual updater boundary

0.5.0 includes the signed production Sparkle updater, invoked only by the menu. Older 0.4.0 installations need one manual upgrade. Download and installation/relaunch require user consent. Existing login-item state and persistent visibility preferences are retained. GitHub/CDN receives ordinary update-request metadata, never account/usage/card data. The app is ad-hoc signed and not notarized; stop at system security blocks, never remove quarantine or disable Gatekeeper. There is no automatic health rollback.

The verification public key is in source; the private key stays in the maintainer Keychain. Key generation/export and publication require explicit authorization. Never create temporary signing keys. Building does not install or publish. See the [update guide](../../docs/UPDATES.en.md).

## Test/production separation (0.6.26 development)

All local controller commands now default to the Testing app (`UsageTopbarTest`, `local.alex.usage-topbar.testing`). Explicit `USAGE_TOPBAR_CHANNEL=release` selects production. Never use production stop/start/install commands during a testing iteration. Replace only `/Applications/UsageTopbar Testing.app` after verifying its bundle ID; preserve the production app and data. Test builds disable updates/login registration and default the overlay to hidden. Production upgrades are user-initiated after a separately authorized GitHub release.
