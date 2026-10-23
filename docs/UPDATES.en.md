# In-app updates — 0.5.0 (24)

[简体中文](UPDATES.md)

0.5.0 introduces the production manual update channel. **0.4.0 has no updater: install 0.5.0 manually once, then use “Check for Updates…”.** The fixed [signed main feed](https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml) accepts this repository's HTTPS Release ZIPs and increasing integer builds. Stable and beta releases use channel metadata within the same signed feed, as described below.

## User flow and limits

Manual check → available update → user chooses download → archive verification → user confirms installation/relaunch → preferences restored. Checks/downloads can be cancelled and versions skipped. After installation consent, “Install on Quit” is different from cancelling a download. Automatic checks, downloads and installation, forced restart and system profiling are disabled. Invalid sources/signatures and downgrades are rejected.

This release is **ad-hoc signed, without Developer ID or Apple notarization**. A real Edge download and quarantine-preserving extraction were rejected by Gatekeeper assessment on the maintainer Mac. Other Macs may block first installation; smooth first launch is not guaranteed. Stop if blocked and let the user handle the warning. No quarantine removal, Gatekeeper disabling or other security bypass is provided.

Explicit overlay visibility is stored as `overlay.userHidden` in the stable `local.alex.usage-topbar` preferences domain. Upgrading from 0.4.0 starts visible because that version had no persistent visibility choice. Automatic hiding is transient; demos do not write preferences. Layout/contrast follow the current environment. macOS owns login-item state; updates do not register/unregister it. Actual login/reboot remains untested. Existing Codex app-server login is reused without copying or changing credentials.

## Evidence and recovery boundaries

- A separate test channel exercised the actual app and Sparkle standard UI through GitHub HTTPS/CDN discovery, download, signature verification, replacement/relaunch, settings retention and actual AppDelegate child cleanup, using synthetic account data.
- Covered check/download cancellation, skipping, no-update, network/signature errors, interrupted-download retry, missing installer helper and controlled replacement failure after readiness. Old bundles were retained; controlled replacement failure left the signed old app launchable with settings.
- There is **no automatic health-check rollback** after a new version fails to start. Manual restoration of a verified working backup was tested in isolation only; arbitrary disk corruption or power loss is not covered. Wait for app/installer exit, preserve the failed app and keep preferences.
- Programmable-host tests do not prove every standard UI branch. Developer ID, notarization, clean Macs, older systems, real login/logout/reboot and prolonged real-account use remain untested.
- Starting with 0.7.3, the pinned Sparkle validator patch rejects wrong Bundle IDs, missing fields and package/feed build mismatches before installation, while preserving signature checks. Older installed updaters retain their original behavior until upgraded, so publisher-side exact verification remains essential for the first transition. Signatures do not ensure freshness. A compromised signing key compromises publishing authority.

## Maintainer release procedure

1. Increment version/build; run regression, startup, update policy, metadata and relevant installation tests. Production identity is `local.alex.usage-topbar`; never ship test identity/feed or a synthetic server in the production app.
2. Build with `USAGE_TOPBAR_CHANNEL=release USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh`; verify arm64, deployment target, nested signatures and privacy. Package the final ZIP with `ditto -c -k --keepParent`.
3. Run `scripts/sign-update.py` for exact identity/version checks. Only `--sign` accesses the existing Keychain account `ALEXESLAT.usage-topbar`. It signs a validated frozen snapshot, emits SHA-256 and rejects input mutation. Never export keys, pass them in environment variables, upload them to CI or routinely generate/rotate them.
4. Generate and verify the final signed feed:
   ```sh
   SPARKLE=$(scripts/fetch-sparkle.sh)
   "$SPARKLE/bin/generate_appcast" --account ALEXESLAT.usage-topbar --maximum-deltas 0 --download-url-prefix "https://github.com/ALEXESLAT/usage-topbar/releases/download/v$VERSION/" "$RELEASE_DIR"
   python3 scripts/verify-update-release.py "$ZIP" "$APPCAST" --version "$VERSION" --build "$BUILD"
   ```
   This public-key-only gate binds both signatures, identity, exact version/build, URL and length. Save both hashes; never modify signed files.
5. Publish assets for the exact tested commit, download them again and run:
   ```sh
   python3 scripts/verify-update-release.py "$DOWNLOADED_ZIP" "$DOWNLOADED_APPCAST" --version "$VERSION" --build "$BUILD" --expected-sha256 "$ZIP_SHA256" --expected-feed-sha256 "$FEED_SHA256"
   ```
   Make the verified ZIP publicly available before enabling its signed main feed. Check tag, CI, Release state and local menu. Retain a working rollback package; never overwrite immutable old assets.
6. Publication and key generation/export require explicit user authorization; do not request duplicate permission already granted for the current task. Building does not install or publish.

Update requests send ordinary HTTP/connection metadata to GitHub/CDN, without account, usage, card or credential data. Remote release notes, JavaScript and profiling are disabled; signed-feed failures never expire into an unsigned fallback.

[Official setup/security](https://sparkle-project.org/documentation/) · [Customization](https://sparkle-project.org/documentation/customization/) · [Pinned validator](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SUUpdateValidator.m)

## Stable and beta update channels

The Update channel menu shows the installed version and selected channel. Stable is the default; `updates.channel` persists across launches. Beta releases may be unstable. Beta accepts compatible newer beta and stable releases; without a beta candidate, a newer stable release remains eligible. Sparkle handles no-update, request/signature failure and retry without replacing the installed app. The separate developer `UsageTopbar Testing.app` still disables updates. Public betas use the production bundle identity, real history and release build configuration.

Both channels use the same signed `main/updates/appcast.xml`. Stable entries have no `sparkle:channel` and explicitly declare `<sparkle:releaseStatus>published</sparkle:releaseStatus>`. Beta entries require `<sparkle:channel>beta</sparkle:channel>`, `<sparkle:releaseStatus>prerelease</sparkle:releaseStatus>` and a SemVer prerelease such as `1.2.0-beta.1`. Drafts, unknown, missing or inconsistent metadata are excluded. The existing live feed lacks this new status field and has not been changed or re-signed in this task; future candidates require the publication steps below.

Sparkle filters system/hardware compatibility before candidate selection. SemVer precedence selects the newest eligible candidate, including numeric prerelease identifiers; integer builds must also strictly increase and the marketing version must not decrease. Stable beats the same version's beta, beta.10 beats beta.2, and +build metadata does not affect precedence. Returning to stable never downgrades an installed beta; wait for a newer stable release.

Changing channels saves the selection, invalidates old callbacks and cancels/dismisses the old candidate through Sparkle callbacks, then checks again after the old session ends. Once installation or deferred restart has been committed, switching is refused and the original selection remains until installation finishes. Download/install consent remains manual.

### Minimal beta publication procedure (not executed here)

1. Build with production identity, release configuration, real history, a SemVer prerelease and a globally increasing build; complete tests and package validation.
2. In a release staging directory, retain stable and beta items in one feed. Use `generate_appcast --channel beta` for new beta items and the default channel for stable items. Add the matching `sparkle:releaseStatus`, retaining embedded version-bound notes, architecture and OS requirements. Re-sign the final feed with the existing account: `sign_update --account ALEXESLAT.usage-topbar appcast.xml`. Do not modify signed artifacts afterward.
3. `verify-update-release.py` checks channel/status/version consistency in addition to the existing two signatures, identity, URL and length checks. Publish a non-draft GitHub prerelease, save its public REST Release JSON, and pass `--release-json release.json` during downloaded-artifact verification to confirm draft=false, prerelease=true and the exact tag (stable requires prerelease=false). Only then enable the same main signed feed. Never include a draft in the feed.
4. This task uses synthetic data only: no release creation, private keys or installation. Run `tests/run-updater.py`, `tests/test-update-channels.py` and `tests/run-release-config.py` with Python 3. Actual channel-switch/download/install UI acceptance remains outstanding.
