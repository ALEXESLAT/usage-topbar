# Usage Topbar 0.4.0

**English** · [简体中文](RELEASE_NOTES.md)

**0.4.0 (build 20) · Apple Silicon (arm64) · macOS 13+**

- Compact overlay with a centered percentage, pts aligned to its actual left edge, card details above throughput, and a Codex menu-bar mark.
- Countdown follows the actual reset deadline; available reset-card count and earliest expiry use `Exp. MM/dd`, with `--` for unavailable details.
- Initial reads and recovery animate digits and bar together from zero to the actual value over about 0.8 seconds with ease-out. Routine refreshes do not replay it; reduced motion is respected.
- Monitoring starts directly within the disclosed scope, without a per-launch dialog. Optional launch at login defaults off for new users and preserves existing system registration.
- Background and manually hidden tracking checks fall back to one second; foreground and automatic hiding retain 0.2-second checks with immediate event handling. Presentation deduplication and font measurement caching avoid repeated work.

- [DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.dmg)
- [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/UsageTopbar-0.4.0-macOS-arm64.zip)
- [Plugin / source](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/usage-topbar-plugin-0.4.0.zip)
- [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.4.0/SHA256SUMS.txt)

Quit the old version and move the app into `/Applications`. A signed-in Codex/ChatGPT installation with app-server is required. Opening starts the disclosed monitoring directly, without a per-launch dialog.

**Ad-hoc signed, not notarized by Apple.** Apple Silicon only. Follow macOS per-app opening instructions; do not disable Gatekeeper.

Validation: local optimized arm64 build; synthetic usage/cards/countdown/connection/layout regressions; startup, recovery animation and login-controller tests; light/dark and 1×/2× synthetic renders; packaged version, signature and checksums. Earlier installation tests of the same feature source covered ordinary repeated opening, exit cleanup and live startup; release installation version and process state are checked separately.

Limits: reduced motion, disconnection, missing screen permission and login registration mainly use synthetic tests. No reboot/login cycle, older macOS, physical multi-display/notch combinations or long-term battery test. No whole-app energy-saving claim, reliable cross-process card-consumption detection, or real-card redemption.

Existing login reads OpenAI usage/cards. Whole-Mac throughput, window geometry and tiny brightness samples with existing permission stay local. Missing permission falls back without requesting access; no OCR or saved screenshots. Quitting stops requests and sampling.

[Installation and privacy](docs/USAGE.en.md) · [Changelog](CHANGELOG.en.md)

> The software and documentation were written by artificial intelligence.
