---
name: manage-usage-topbar
description: Start, stop, preview, rebuild, or inspect the local Usage Topbar macOS overlay. Use when the user asks to show live Codex remaining usage, open the usage bar, run a safe demo, check its status, or manage the usage-topbar companion app.
---

# Manage Usage Topbar

Use the deterministic controller at `scripts/control.sh`.

## Privacy gate

Before `start`, state all of the following and obtain explicit task-specific consent:

- Data: Codex rate-limit percentages, reset times, credit balance, cumulative upload/download byte counts from the Mac's active external interfaces, ChatGPT window bounds, the average luminance of a 12×12 px title-bar sample, and the public IP, connection time, plus standard connection metadata produced by authenticated OpenAI usage requests.
- Purpose: render and position the local usage overlay, display whole-Mac live throughput and Codex connectivity, then select readable light or dark text.
- Operation: poll the local Codex app-server with `account/rateLimits/read` every 30 seconds; use the authenticated request result to drive connection status; locally calculate interface byte deltas every two/five seconds; enumerate only ChatGPT window geometry; and use ScreenCaptureKit locally to sample a tiny color region without recognizing text or reading network contents.
- Recipient/service: OpenAI receives the authenticated rate-limit read and normal connection metadata; no third party receives data, and interface statistics, window geometry, plus color samples stay on the Mac.

The app repeats this disclosure in a native dialog on every live launch. Do not bypass it. Never trigger a macOS Screen Recording permission prompt automatically: sample colors only when permission is already available, otherwise silently fall back to the system appearance. `demo`, `preview`, `status`, `stop`, and `build` do not read account usage, interface statistics, window geometry, or screen colors.

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

Prefer `demo` for validation because it uses generated sample percentages. Use `preview` to regenerate the plugin screenshot without launching a persistent process.

If `start` fails, run `build`, retry once, then report the exact error. Do not patch or replace `ChatGPT.app`.
