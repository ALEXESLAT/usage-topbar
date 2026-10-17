# Usage Topbar 0.6.26

[简体中文](RELEASE_NOTES.md)

**0.6.26 (build 51) · Apple Silicon / macOS 13+**

- Local quota history with a four-day overview, scrollable seven-day detail, hover readouts and reset events. Retain three months of real observations with explicit gaps.
- Preserve raw observations while caching curves and gradients. Hidden and minimized history views refresh when presented again.
- Save snapshots on a serial background queue, coalesce changes during writes, retry failures, and flush the latest snapshot before sleep or termination.
- Production can safely continue real Testing history with validation, deduplication, production-first conflict resolution and migration backups. Testing preferences and simulated data are not imported.

**0.5.0 users can choose “Check for Updates…” in the existing app and confirm download, installation and relaunch.** No manual replacement is needed first. Versions 0.4.0 and earlier require manual installation. Production retains its identity, preferences domain and signed update channel; Testing remains separate.

[DMG](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/UsageTopbar-0.6.26-macOS-arm64.dmg) · [ZIP](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/UsageTopbar-0.6.26-macOS-arm64.zip) · [Plugin/source](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/usage-topbar-plugin-0.6.26.zip) · [SHA-256](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.6.26/SHA256SUMS.txt)

Local synthetic regressions cover history, migration, charts, lifecycle, startup, update policy and package metadata. Release verification binds the existing signing key, exact identity/version/build and downloaded hashes. Reduced main-thread save latency does not imply proportional total CPU or battery gains. Long-running real sessions, older systems and physical trackpads are not fully validated.

**Ad-hoc signed, not Apple notarized.** First installation may be blocked by macOS. There is no automatic health rollback. Updates require user initiation and confirmation; downloads and installation are not automatic.

[Update and recovery boundaries](docs/UPDATES.en.md) · [Usage and privacy](docs/USAGE.en.md)
