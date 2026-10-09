# Install and use Usage Topbar

**English** · [简体中文](USAGE.md)

This guide covers **0.5.0 (24)** for Apple Silicon (arm64), macOS 13+. [Project overview](../README.en.md) · [Downloads](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.5.0)

## Install or update

1. Install and sign in to the Codex/ChatGPT desktop application, with a usable Codex app-server.
2. Download the [arm64 DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.dmg) or [arm64 ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.zip). When updating, quit the previous instance from its menu-bar menu first.
3. Place `UsageTopbar.app` in `/Applications`. Do not use the app inside a mounted DMG as your permanent installation.
4. Open the app. This release is ad-hoc signed and not notarized, so macOS may display a developer-verification warning. Verify the source and follow the system's per-app opening prompts. Do not disable Gatekeeper or change global security settings.
5. The release starts the authorized monitoring immediately without a launch dialog. It adds no login item automatically, credentials, or system permissions; quitting stops sampling and requests.

To check your download, run the following in the download folder and compare the result with the same filename in [SHA256SUMS.txt](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/SHA256SUMS.txt).

```sh
shasum -a 256 UsageTopbar-0.5.0-macOS-arm64.dmg
```

No API key or copied account credentials are needed. The app checks registered Codex/ChatGPT application locations and common CLI paths. If none is found, it displays `Codex not found`.

## Everyday controls

- The Codex menu-bar item shows remaining usage. Its menu offers immediate refresh, overlay visibility, and quit controls.
- Live mode shows the overlay only when Codex/ChatGPT is in the foreground and there is enough space above its window. Switching applications, maximizing/full-screening, or moving near the screen's top edge can hide it. The menu-bar item remains available, although macOS can hide extras when the menu bar is crowded.
- The overlay shows the most constrained Codex window and its matching reset countdown. `points` is the returned balance. `--%` means unknown/unavailable; `0%` is a valid zero reading.
- Green means the latest valid usage request succeeded; yellow means checking; red means a request failed or the local network is unavailable. Throughput cannot turn a failed usage request into a successful one.
- `↓` and `↑` summarize selected external interfaces across the Mac. They do not measure maximum connection speed, inspect traffic contents, or isolate Codex traffic.

Usage normally refreshes every 30 seconds. Manual refresh does not stack another request while initialization or a request is already pending. Failures, process exits, and timeouts follow the relevant recovery paths. Sleep suspends monitoring; wake requests new data rather than continuing to display the pre-sleep percentage.

The card icon shows available reset cards. `Exp. MM/dd` is the earliest expiry in local time; `Exp. --` means unknown and `Exp. none` means all known cards have no expiry. Incomplete details do not imply a guessed date. The app never redeems cards and cannot reliably detect card consumption by another process.

Initial reads and recovery fill from zero to the actual percentage over about 0.8 seconds. Routine updates do not replay it, and reduced motion shows the value immediately. The countdown uses the absolute reset deadline.

## Management commands

Run these from the `v0.5.0` source or plugin-package root. `start` and `demo` use **the version installed at `/Applications/UsageTopbar.app`**.

```sh
scripts/usage-topbar.sh status
scripts/usage-topbar.sh demo
scripts/usage-topbar.sh start
scripts/usage-topbar.sh preview
scripts/usage-topbar.sh build
```

| Command | Actual behavior |
| --- | --- |
| `status` | Returns `running` or `stopped`; restricted process inspection returns `unknown` and an error, not evidence that the app stopped |
| `demo` | Opens another instance with generated data, without account usage, live throughput, or window-color reads; quit it through that instance's menu |
| `start` | Opens the installed app and immediately starts the documented monitoring |
| `preview` | Prints the existing repository preview-image path; it does not render a new image |
| `build` | Produces a temporary development app without replacing `/Applications` |
| `stop` | Stops all processes named `UsageTopbar`; prefer the individual instance's menu when closing only a demo |

The same commands are available through `skills/manage-usage-topbar/scripts/control.sh`. Direct startup has been explicitly authorized for the documented scope; do not request the same consent again. New data, recipients, or permissions require separate authorization.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Installed app not found | Check `/Applications/UsageTopbar.app`; building is not installation |
| `Codex not found` | Confirm that the desktop app contains an executable CLI; developers can use `CODEX_BINARY` when directly starting the process |
| `--%`, red status, or timeout | Check Codex sign-in and network connectivity, then try immediate refresh; unknown does not mean exhausted |
| Menu-bar item but no overlay | Bring Codex forward, move the window down to leave space, and check that the overlay was not manually hidden |
| No `∞` item | Check whether the app started; macOS controls which extras remain visible when space is limited |
| Contrast does not follow the window | System appearance is the intended fallback on macOS 13 or without existing Screen Recording permission; changing permissions is not required to use the app |

Developer example for an existing custom CLI (monitoring starts directly):

```sh
CODEX_BINARY="/absolute/path/to/codex" /Applications/UsageTopbar.app/Contents/MacOS/UsageTopbar
```

## Uninstall

Quit Usage Topbar from its menu-bar menu, then move `/Applications/UsageTopbar.app` to Trash. If you enabled Launch at login, disable it in the app menu or remove its system login item before uninstalling. The default is off.

Removing Usage Topbar does not require deleting Codex/ChatGPT, signing out of those applications, or removing their account data. Do not delete Codex credentials, configuration, or history to uninstall this tool.

## Report a problem

Use [GitHub Issues](https://github.com/ALEXESLAT/usage-topbar/issues). Include the Usage Topbar version/build, macOS version, Apple Silicon model, whether an external display is connected, reproduction steps, expected versus actual behavior, and visible error text. A device serial number is not needed.

Issues are public. Do not submit account credentials, API keys, access tokens, personal usage/balance snapshots, or unreviewed logs. Redact accounts, task contents, and other private information from screenshots; use a text description if you cannot safely redact them. There is no automatic diagnostic-upload feature.

## Privacy and compatibility

Live mode reads Codex usage, reset times, and points; it calculates interface deltas and Codex window placement locally. On macOS 14+ with existing Screen Recording permission, it measures average luminance in a tiny title-bar region. It does not request permission automatically or perform OCR. OpenAI receives usage requests and normal connection metadata; interface statistics, window geometry, and color samples are not sent to third parties.

Usage Topbar itself does not persist those data or credentials. Quitting stops monitoring; Codex's own data handling follows its settings.

The minimum deployment target is macOS 13. Native Liquid Glass is used on macOS 26+, with SwiftUI material on earlier supported systems. See the [release notes](../RELEASE_NOTES.en.md) for tested and untested configurations. Intel Macs are not supported by 0.5.0.

- Launch at login is off by default. The menu registers the macOS login item only when clicked; pending approval is shown without accepting system prompts. Click again to unregister.

0.4.0 users must install 0.5.0 manually once, then use “Check for Updates…” with the signed production feed. Download/install/relaunch require consent. Visibility preferences persist; login-item state is unchanged. No automatic health rollback; see [update limits](UPDATES.en.md).
