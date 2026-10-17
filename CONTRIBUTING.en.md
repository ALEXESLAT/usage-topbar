# Development and contributions

**English** · [简体中文](CONTRIBUTING.md)

## Build from source

The default branch `main` now contains the 0.5.0 release source and current documentation. **Check out the `v0.5.0` tag to reproduce this exact release.**

Use an Apple Silicon Mac and an Xcode/Swift toolchain with the macOS 26 SDK or newer. Regression tests additionally require Python 3. The app's deployment target remains macOS 13+.

```sh
git clone --branch v0.5.0 --depth 1 https://github.com/ALEXESLAT/usage-topbar.git
cd usage-topbar
scripts/usage-topbar.sh build
python3 tests/run.py
python3 tests/run.py --render /tmp/usage-topbar-previews
```

The arm64 app is written to `${TMPDIR:-/private/tmp}/usage-topbar-testing/UsageTopbar Testing.app`. Building does not install it. Source, management skills, and tests are also included in the [plugin package](https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/usage-topbar-plugin-0.5.0.zip). Package documentation remains the release-time snapshot; this repository carries the updated guides.

## Propose a change

Check existing issues first. Include reproduction steps and relevant regression results for behavior changes, and anonymous demo images for UI changes. Keep arm64, the macOS 13 deployment target, and material fallbacks for older systems. Update both language sets. Never commit credentials, real usage, logs, or local build directories.

CI runs mock regressions, builds, architecture/signature checks, and UI renders and startup regressions on a standard macOS 26 arm64 runner. Check artifacts last 7 days and are not official releases. See [Actions](https://github.com/ALEXESLAT/usage-topbar/actions/workflows/ci.yml). This does not validate older systems, physical display setups, or prolonged real-account use.

## Releases and license

Use [Releases](https://github.com/ALEXESLAT/usage-topbar/releases) for official builds. Before publishing, check version/build numbers, tests, arm64 architecture, signature, checksums, and attachments. CI does not publish releases.

Licensed under the [MIT License](LICENSE). Copyright © 2026 ALEXESLAT. Preserve the copyright and license notices when using, modifying, or distributing the software. Third-party content retains its original terms.

[Usage guide](docs/USAGE.en.md) · [Home](README.en.md)

## Updater maintenance

Builds now need Python 3 and HTTPS access to GitHub for pinned Sparkle 2.10.0. Set `USAGE_TOPBAR_DEPENDENCY_CACHE` to choose the cache. `python3 tests/run-updater.py` creates no keys. The app includes the upstream framework and external-component licenses. See [update development boundaries](docs/UPDATES.en.md).

## Extension points and history sources

Prepare lightweight interfaces for known future directions without affecting core behavior or performance. Separate collection, versioned persistence and presentation; preserve compatibility when evolving formats. Avoid speculative abstractions or additional background polling.

The read-only `HistoryDataSource` separates charts from `QuotaHistoryStore` (v1 persistence). Testing defaults to an in-memory deterministic 14-day fixture anchored to the last half-hour at startup, labeled “模拟数据”. It never reaches real-time quota or persistence. Quit Testing, run `defaults write local.alex.usage-topbar.testing history.useSimulatedData -bool false`, then reopen for real history; true or deleting this key restores simulation. Release compilation excludes fixtures, ignores this preference, and forces `UsageTopbarHistorySource=real`; pre-sign validation rejects missing or simulated metadata. Check the release binary's `--variant-info` reports `historySource=real` before publication.

### Automatic real-history continuation (0.6.6)

Testing and production retain separate v1 files and preference domains. Normal app replacement preserves external data and production preferences. Production startup now imports an atomic snapshot from Testing through `HistoryMigration`; no manual copying or extra polling is needed. Testing builds and metadata-only commands never auto-import. Later production starts can pick up newly collected records.

Validate version, fields, account/card digests, series and evidence sources; reject simulations/unknown versions, skip expired/future source records. Deduplicate by account/series/timestamp, keeping production on conflicts and the first incoming duplicate. With no additions, do not write or create backups. Before a merge, back up the source, existing destination and a count/conflict report under `migration-backups/<UUID>` with private permissions. Verify the destination has not changed, write atomically and read back. Roll back on failure; leave source/preferences untouched. Errors are visible in the real-history chart and retried on restart. Normal three-month retention still applies.

This iteration rehearses only isolated files and a read-only local snapshot of actual Testing history, without modifying production data or installing/publishing production. Run `python3 tests/run-migration.py [optional-source-history-path]` to validate full sample/count/range preservation. User testing precedes separately authorized GitHub publication and the user's own update. First production launch then continues matching-account history automatically.


### 0.6.25 chart rendering and acceptance

Keep the 6pt stroke, 50% rounding, eight-interval local tail fits, 2h gap threshold, 4/7-day viewports and 4.5% reset bands. Preserve raw samples; crosshair hits use the visible curve cache. A separate date-axis backing layer fixes native sibling scroll-blit ghosting.

Detail hover has separate axis and point percentages plus coordinate time below. Missing regions show time only; avoid reset interpolation and clear on exit. Four-day hover uses only one percentage and a locator dot, with click-through to detail. Use continuous circular arcs with rounded filled heads, an open card corner and a filled four-point star inside the special ring at compact sizes.

Unlocked native-window checks passed with foreground-guarded automatic HID scrolling, momentum and both elastic boundaries. Percentage/gap/exit screenshots are retained. This is not physical-trackpad acceptance. Compact previews were checked at actual dimensions; detail has native captures. The test-only --exercise-history-scroll records a finite trace, with no permanent listener.


Gradient validation: `python3 tests/run-gradient.py` checks drafts, preview, save/cancel, formats and an isolated preference domain. `python3 tests/run.py --gradient` compares rendered pixels at 25/75/100% for fixed-track colors and right-edge clipping. The editor is Testing-only; production does not read Testing settings.

### Iteration validation and foreground input

Batch consecutive feedback before one Testing installation. Prefer background builds, unit tests, affected regressions and offscreen rendering; reuse valid evidence instead of repeating all-state screenshots.

Use minimal screenshots of affected controls. Before moving the user's pointer, typing, changing foreground focus or themes, explain the operation and wait for fresh explicit consent. Earlier acceptance consent does not carry forward. Foreground automation is paused until renewed consent. Report untested items honestly.

Remove only known reproducible temporary outputs created by this task. Preserve source, real history, user files, final deliverables, necessary rollback copies and verification evidence.
