# Usage Topbar 0.5.0

[简体中文](RELEASE_NOTES.md)

**0.5.0 (build 24) · Apple Silicon / macOS 13+**

- Adds “Check for Updates…” through Sparkle 2.10.0: a signed production feed, verified downloads, and user-confirmed installation/relaunch.
- No automatic checks, downloads or installation, forced restart, or system profiling.
- Persists explicit overlay visibility across relaunches and updates; existing login-item state is preserved.
- Frozen-snapshot signing, exact package identity/version checks, and final ZIP/feed/digest verification before and after publication.

**0.4.0 users must manually install this release once**, then use the signed production update feed. Installation/relaunch requires consent. Existing login-item state is retained; new installations default off.

**Ad-hoc signed; not Apple notarized.** Gatekeeper may block quarantined browser downloads; rejection was observed in an actual download assessment. Smooth first launch on other Macs is not guaranteed. No security bypass is provided.

[DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.dmg) · [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.zip) · [Plugin/source](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/usage-topbar-plugin-0.5.0.zip) · [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/SHA256SUMS.txt)

Validation covers synthetic regressions, startup, update policy, metadata, nested signatures and final artifacts. An isolated actual app exercised standard UI, HTTPS/CDN upgrade and settings retention. Controlled download retry, replacement failure preserving the old app and manual backup restoration were tested. **Automatic health rollback is not implemented.** Developer ID/notarization, clean Macs, real login/reboot, arbitrary disk failures and every standard UI branch remain untested.

The production identity and main feed contain no test substitutions or synthetic account server. Existing login is used for usage/card reads; throughput, window positioning and tiny brightness samples under existing screen permission remain local. No new permissions, saved screenshots, OCR or card redemption. Quitting stops requests and sampling.

[Update process and limits](docs/UPDATES.en.md) · [Usage and privacy](docs/USAGE.en.md)
