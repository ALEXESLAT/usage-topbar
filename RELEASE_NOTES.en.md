# Usage Topbar 0.7.0

**DRAFT — not published. The public stable feed remains 0.5.0 (24); 0.6.26 (51) was withdrawn to draft with its tag and assets preserved.**

- Release and Testing both support custom gradients, including startup loading, live preview, save/cancel and 4/7-day chart linkage. Each channel retains its own preferences.

[简体中文](RELEASE_NOTES.md)

**0.7.0 (build 52) · Apple Silicon / macOS 13+**

- Local quota history with a four-day overview, scrollable seven-day detail, hover readouts and reset events. Retain three months of real observations with explicit gaps.
- Preserve raw observations while caching curves and gradients. Hidden and minimized history views refresh when presented again.
- Save snapshots on a serial background queue, coalesce changes during writes, retry failures, and flush the latest snapshot before sleep or termination.
- Production can safely continue real Testing history with validation, deduplication, production-first conflict resolution and migration backups. Testing preferences and simulated data are not imported.



Local synthetic regressions cover history, migration, charts, lifecycle, startup, update policy and package metadata. Release verification binds the existing signing key, exact identity/version/build and downloaded hashes. Reduced main-thread save latency does not imply proportional total CPU or battery gains. Long-running real sessions, older systems and physical trackpads are not fully validated.

**Ad-hoc signed, not Apple notarized.** First installation may be blocked by macOS. There is no automatic health rollback. Updates require user initiation and confirmation; downloads and installation are not automatic.

[Update and recovery boundaries](docs/UPDATES.en.md) · [Usage and privacy](docs/USAGE.en.md)

Candidate gate: dual-configuration offscreen checks do not replace production menu clicks, stop dragging or physical scrolling acceptance. Long-running CPU, memory and energy for 0.7.0 have not been measured. Keep this release in draft until acceptance and explicit publication authorization.
