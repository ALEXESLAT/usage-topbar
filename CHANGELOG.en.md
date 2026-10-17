# Changelog

## 0.7.0 (52, draft candidate)

- Enable gradient loading, editing, preview, save/cancel and chart linkage in both Release and Testing, retaining separate preference domains.
- Read menu/client versions from bundle metadata; add dual-configuration offscreen regression coverage.
- 0.6.26 is withdrawn to draft; the public update feed remains on 0.5.0.

## 0.6.26

- Encode and atomically save history snapshots on a serial background queue, coalescing changes during writes. Preserve retries and synchronous sleep/termination flushes; ignore stale completions.
- Skip data refreshes for hidden or minimized history views and refresh on presentation or restore. Keep the history format and chart appearance unchanged.
- Add regression coverage for asynchronous retries, account changes, shutdown ordering, and hidden views.

## 0.6.25 (unreleased testing build)

- Retry failed history writes on subsequent reads and persist retention-only pruning without changing sampling. Cache gradient stroke masks and palettes with geometry/settings invalidation; raster output remains identical.

- Fix date-label ghosting observed after elastic scrolling by replacing the full transparent axis surface each frame; revalidated native scrolling and hover label restoration.

- History curves reuse all progress-gradient stops on the fixed 0–100% vertical axis (bottom=start, top=end), synchronized with preview/save/cancel; reset bands and markers remain independent.

- Thicken all reset-arrow strokes by 15%, coordinate their heads, and inset the arc centerline to preserve outer size in both chart views.

- Enlarge the special-reset inner star by 25% without changing its ring; separate the card edge from the reset arc to avoid small-size raster merging. Validated offscreen only.

- Use muted sage history curves in both themes and equal 30×30 pt add/remove buttons; preserve custom progress gradients.

- Four-day preview adds a vertical locator and compact time label with one percentage; gaps show only time, and one click opens details.

- Explicit Confirm saves and closes the gradient editor; cancel or closing reverts.
- Subtle local noon/midnight lines deduplicate midnight and follow daylight-saving calendar boundaries. Date labels retain their midnight anchors; noon-centered labels remain a proposal.
- Reset bands use 5pt detail / 3pt compact corners, clamped for short bands without expanding their extent.

- Default quota gradient uses muted sage-to-mint, preserving saved user colors.
- Four/seven-day reset bands span only observed before/after quota values. Missing prior values create no band; exact unions avoid double opacity or invented lower coverage.

- Testing menu adds a gradient editor with up to eight movable color/alpha stops, add/delete, live preview, save/cancel and restore default. Drafts and previews do not persist; closing cancels. Saves use only the Testing preference domain.
- The quota bar uses a fixed full-track gradient. Decreasing quota clips only the right edge without threshold color changes or rescaling the gradient; quota and refill animation semantics remain.
- History restores full-strength native background blur with adaptive tint instead of lowering material opacity and exposing readable background text.


## 0.6.16 (unreleased testing build)

- Full-size history content blends with a transparent, title-hidden title bar, retaining native close controls and blank-area dragging. Axis values move slightly right.
- More translucent history surfaces with solid protection under Reduce Transparency.
- Light-mode lines and reset markers use semantic system teal, without reading or assuming a Codex custom accent.
- Tightens the four-day popover from 430×215pt to 410×195pt, reducing margins without shrinking text or the readable plot area.


## 0.6.12 (unreleased testing build)

- Detail hover has separate axis percentage, point percentage and coordinate date/time labels with tick and edge avoidance; missing intervals show time only.
- The four-day popover uses one percentage label and a locator dot; clicking still opens seven-day detail.
- Retains 50% smoothing, eight-interval tail fitting and compact reset icons. Local commands default to the isolated Testing app.


History readouts and Return to Now use native Liquid Glass on macOS 26+, compatible material on older systems, and solid surfaces with Reduce Transparency. History follows the effective theme at runtime. The plot itself has no glass overlay.

## 0.6.10 (unreleased testing)

- Isolate the date backing layer to fix native scroll ghosting.
- Percentage-only crosshair label; missing regions hide the value.
- Rounded filled arrowheads, open card corner and filled internal star, retaining compact sizes.
- Native automated scrolling, momentum and boundary checks; real collection and safe migration retained.


## 0.6.8 (unreleased testing)

- Isolated simulated history with real collection preserved; release builds force the real source.
- Safe production-startup import of Testing history with deduplication, production conflict priority, backups, atomic verification and rollback.
- 50% rounding, eight-interval tail refits, 4.5% reset bands, compact circular symbols and detail crosshairs.
- Separate viewport date axis removes the scroll-cache/edge-clamping artifact path. Final live interaction acceptance remains pending while the Mac is locked.


**English** · [简体中文](CHANGELOG.md)

The current public release is **[0.5.0 (24)](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.5.0)**. Historical platform support does not define current support.

## 0.6.4 (29) — Unreleased testing build

- 30% visual smoothing first simplifies each continuous run within 1.8 screen points, then rounds 30% of adjoining visual edges so dense samples cannot collapse corner radii.
- Retains opaque 6pt strokes, two-hour gap policy and identity/reset boundaries. Raw storage and hover values stay unchanged.

## 0.6.3 (28) — Unreleased testing build

- 6pt normal strokes and 20% corner rounding replace the 0.6.2 defaults (3pt/10%).

- Uniform opaque normal strokes avoid alpha buildup at neighboring caps/isolated observations.
- Same-account/window gaps shorter than two hours connect as trends; gaps of two hours or more use a horizontal last-observed dash. Reset/identity boundaries stay split. Neither style invents intermediate observations.
- Record reasons for new gaps; retain unknown causes in older data rather than guessing.

## 0.6.2 (27) — Unreleased testing build

- Stroke each continuous run as a single path; isolate solid and dashed graphics states.
- Round corners within 10% of each adjoining edge, without modifying observations or hover values. This is not a quota error allowance.
- Testing-only --show-history opens the running test app history for targeted on-screen verification.

## 0.6.1 (26) — Unreleased testing build

- Hide the quota selector when there is only one period; retain multi-period switching.
- Use a 3-point monotone smooth trend line without permanent markers on connected samples; highlight real samples on hover.
- Never smooth across gaps/resets or overshoot observed endpoints. Isolated evidence remains a dot; missing intervals retain faint horizontal dashes.

## 0.6.0 (25) — Unreleased

- Local builds default to an isolated Testing app, executable, bundle/preferences ID and history directory. Testing disables updates/login items and initially hides its overlay; production updates accept matching release ZIP names only.

- Left-click the percentage for four days of history; click the chart for a seven-day window. Right-click retains the original menu.
- Native horizontal scrolling, inertia, boundary elasticity and return-to-now; fixed 0–100% scale with actual sample values on hover.
- Reuses fresh successful reads, samples every 30 minutes plus startup/recovery/reset observations, isolates account digests and quota windows, and retains three calendar months locally.
- Gaps hold the last value with a faint horizontal dash; upward resets break the line. Evidence distinguishes scheduled, redeemed-card and inferred special resets; insufficient evidence stays unknown.
- No invented/imported history; missing account IDs disable recording. Existing light/dark contrast drives the chart, not an unsupported custom Codex theme API.

## 0.5.0 (24) — 2026-10-09

- Adds “Check for Updates…” through Sparkle 2.10.0: a signed production feed, verified downloads, and user-confirmed installation/relaunch.
- No automatic checks, downloads or installation, forced restart, or system profiling.
- Persists explicit overlay visibility across relaunches and updates; existing login-item state is preserved.
- Frozen-snapshot signing, exact package identity/version checks, and final ZIP/feed/digest verification before and after publication.

## 0.4.0 (20) — 2026-10-09

- Compact overlay with a centered percentage, pts aligned to its actual left edge, card details above throughput, and a Codex menu-bar mark.
- Countdown follows the actual reset deadline; available reset-card count and earliest expiry use `Exp. MM/dd`, with `--` for unavailable details.
- Initial reads and recovery animate digits and bar together from zero to the actual value over about 0.8 seconds with ease-out. Routine refreshes do not replay it; reduced motion is respected.
- Monitoring starts directly within the disclosed scope, without a per-launch dialog. Optional launch at login defaults off for new users and preserves existing system registration.
- Background and manually hidden tracking checks fall back to one second; foreground and automatic hiding retain 0.2-second checks with immediate event handling. Presentation deduplication and font measurement caching avoid repeated work.

## 0.3.1 (19) — 2026-10-09

- Apple Silicon (arm64) only, macOS 13 minimum.
- Unknown/failed usage displays `--%`; only Codex usage is selected, with duration and reset tied to its most constrained window.
- Initialization/read timeouts, matching responses, bounded retries, and sleep/wake recovery.
- Two-dimensional display positioning, scale and safe-area handling, with a menu-bar fallback when there is no room above the window.
- Actual elapsed sampling time and per-interface baselines reduce anomalies after interface changes, rollover, and sleep.
- Synthetic regression tests do not read real account data. See [release notes](RELEASE_NOTES.en.md) for validation limits.

This documentation update occurred after release. Packages were not rebuilt or replaced; their internal documentation remains the release-time snapshot.

## 0.3.0 (18) — retained historical tag; no release

The [source tag](https://github.com/ALEXESLAT/usage-topbar/tree/v0.3.0) was pushed before the platform scope changed and retains the dual-architecture build configuration from that point. The Apple Silicon-only release moved to 0.3.1 to preserve tag history. Download 0.3.1; the 0.3.0 tag does not represent a delivered installer release.

## 0.2.6 (17) — 2026-10-09

[Historical release](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.6): accumulated 0.2.5 development work plus connection and window-ordering fixes. It provided a universal DMG and an arm64 ZIP. Current 0.3.1 support is arm64 only.

## Earlier versions

- 0.2.5 (16): development-branch and local-delivery version, without a same-named GitHub release; its work was incorporated into later releases.
- [0.2.3](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.3): historical arm64 release improving attachment, foreground visibility, and ordering.
- [0.2.1](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.1) and [0.2.0](https://github.com/ALEXESLAT/usage-topbar/releases/tag/v0.2.0): original notes and assets remain available for historical reference.
