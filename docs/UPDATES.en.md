# In-app updates — 0.5.0 (24)

[简体中文](UPDATES.md)

0.5.0 introduces the production manual update channel. **0.4.0 has no updater: install 0.5.0 manually once, then use “Check for Updates…”.** The fixed [signed main feed](https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml) accepts this repository's HTTPS Release ZIPs and increasing integer builds. The retained test prerelease uses a separate branch.

## User flow and limits

Manual check → available update → user chooses download → archive verification → user confirms installation/relaunch → preferences restored. Checks/downloads can be cancelled and versions skipped. After installation consent, “Install on Quit” is different from cancelling a download. Automatic checks, downloads and installation, forced restart and system profiling are disabled. Invalid sources/signatures and downgrades are rejected.

This release is **ad-hoc signed, without Developer ID or Apple notarization**. A real Edge download and quarantine-preserving extraction were rejected by Gatekeeper assessment on the maintainer Mac. Other Macs may block first installation; smooth first launch is not guaranteed. Stop if blocked and let the user handle the warning. No quarantine removal, Gatekeeper disabling or other security bypass is provided.

Explicit overlay visibility is stored as `overlay.userHidden` in the stable `local.alex.usage-topbar` preferences domain. Upgrading from 0.4.0 starts visible because that version had no persistent visibility choice. Automatic hiding is transient; demos do not write preferences. Layout/contrast follow the current environment. macOS owns login-item state; updates do not register/unregister it. Actual login/reboot remains untested. Existing Codex app-server login is reused without copying or changing credentials.

## Evidence and recovery boundaries

- A separate test channel exercised the actual app and Sparkle standard UI through GitHub HTTPS/CDN discovery, download, signature verification, replacement/relaunch, settings retention and actual AppDelegate child cleanup, using synthetic account data.
- Covered check/download cancellation, skipping, no-update, network/signature errors, interrupted-download retry, missing installer helper and controlled replacement failure after readiness. Old bundles were retained; controlled replacement failure left the signed old app launchable with settings.
- There is **no automatic health-check rollback** after a new version fails to start. Manual restoration of a verified working backup was tested in isolation only; arbitrary disk corruption or power loss is not covered. Wait for app/installer exit, preserve the failed app and keep preferences.
- Programmable-host tests do not prove every standard UI branch. Developer ID, notarization, clean Macs, older systems, real login/logout/reboot and prolonged real-account use remain untested.
- The ad-hoc Sparkle path may accept a trusted-signed wrong bundle ID or a package/feed build mismatch. Publisher-side exact checks reduce mistakes; they are not an independent client identity boundary. Signatures do not ensure freshness. A compromised signing key compromises publishing authority.

## Maintainer release procedure

1. Increment version/build; run regression, startup, update policy, metadata and relevant installation tests. Production identity is `local.alex.usage-topbar`; never ship test identity/feed or a synthetic server in the production app.
2. Build with `USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh`; verify arm64, deployment target, nested signatures and privacy. Package the final ZIP with `ditto -c -k --keepParent`.
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
