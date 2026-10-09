---
name: manage-usage-topbar
description: Start, stop, preview, rebuild, or inspect the local Usage Topbar macOS overlay. Use when the user asks to show live Codex remaining usage, open the usage bar, run a safe demo, check its status, or manage the usage-topbar companion app.
---

# Manage Usage Topbar

Use the deterministic controller at `scripts/control.sh`. The current release is 0.4.0 (20), for Apple Silicon / macOS 13+. See [installation and usage](../../docs/USAGE.md).

## Authorized monitoring scope

The user explicitly authorized direct startup for the following disclosed scope. Opening the app starts it without a repeated confirmation. Do not request the same authorization again; obtain new authorization before expanding this scope:

- Data: Codex rate-limit percentages, reset times, credit balance and reset-card count/expiry details, cumulative upload/download byte counts from the Mac's active external interfaces, ChatGPT window bounds, the average luminance of a 12×12 point title-bar sample, and the public IP, connection time, plus standard connection metadata produced by authenticated OpenAI usage requests.
- Purpose: render and position the local usage overlay, display whole-Mac live throughput and Codex connectivity, then select readable light or dark text.
- Operation: poll the local Codex app-server with `account/rateLimits/read` every 30 seconds; use the authenticated request result to drive connection status; locally calculate interface byte deltas every two/five seconds; enumerate Codex/ChatGPT window geometry for positioning; and use ScreenCaptureKit locally to sample a tiny color region without recognizing text or reading network contents.
- Recipient/service: OpenAI receives the authenticated rate-limit read and normal connection metadata; no third party receives data, and interface statistics, window geometry, plus color samples stay on the Mac.

The release intentionally has no per-launch dialog. It adds no login item automatically or credentials; quitting stops monitoring and terminates its own app-server child. Never trigger a macOS Screen Recording permission prompt automatically: sample colors only when permission is already available, otherwise silently fall back to the system appearance. `demo`, `preview`, `status`, `stop`, and `build` do not read account usage, interface statistics, window geometry, or screen colors.

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

Prefer `demo` for validation because it uses generated sample percentages. `preview` prints the path to the existing repository screenshot; it does not regenerate it. `build` creates a temporary development app and does not install it. `start` and `demo` use `/Applications/UsageTopbar.app`, so they run the installed version.

If `start` reports a missing installed app, follow the installation guide; rebuilding alone will not install it. For other failures, inspect `status` and report the exact error without treating an inspection failure as stopped. `stop` terminates every process named UsageTopbar; prefer the individual instance menu when closing only a demo. Do not patch or replace the Codex/ChatGPT desktop app.

Launch at login is an optional menu setting, off by default. Only a user click registers or unregisters SMAppService.mainApp. Read the actual service status; do not enable it or approve system prompts on the user’s behalf.

## Development updater boundary

Unreleased 0.5.0 adds a manual Sparkle updater; the installed public release may still be 0.4.0. An approved public key is configured; the private key stays in the maintainer’s login Keychain. Building does not enable updates or install the development app. Key generation/export and publication require explicit authorization. Never create temporary test signing keys to bypass that boundary. See [update guide](../../docs/UPDATES.en.md).
