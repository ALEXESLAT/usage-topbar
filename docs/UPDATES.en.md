# In-app updates (0.5.0 development, unpublished)

[简体中文](UPDATES.md)

The public release remains 0.4.0. Development 0.5.0 (21) integrates Sparkle 2.10.0. With explicit approval, a dedicated Ed25519 key was created in the maintainer's login Keychain, account `ALEXESLAT.usage-topbar`. Only `app/update-public-key.txt` is in source. No private key was exported, sent to CI, or published. No public appcast or new release was published.

**Not all upgrade requirements are validated.** Sparkle's ad-hoc path accepted a package signed by the trusted key with a different Bundle ID, and a package whose actual build exceeded its feed build. The new project signing gate rejects these mistakes before signing; this is not an additional client-side package identity check. These limits must be addressed explicitly before release.

## User path

Existing 0.4.0 users must manually install one future official version containing the updater. Afterwards use “Check for Updates…” and confirm download/install/relaunch in Sparkle's UI. Automatic checks/downloads/installations are disabled. Cancelling a download differs from postponing relaunch after agreeing to install. This replaces the app and restarts it; it does not replace running Swift code.

An arbitrary GitHub Release alone is insufficient: the maintainer must publish a valid signed appcast pointing to the signed compatible package. The current development build is not a new official download.

## Maintainer release procedure

Official publication still requires authorization.

1. Increment build and marketing version, synchronize docs, and run regressions and updater tests. Do not regenerate or rotate the existing key for routine releases.
2. Build with `USAGE_TOPBAR_REQUIRE_UPDATER=1 scripts/build-overlay.sh`. The repository public key is included automatically. Verify main arm64 executable, deployment target and nested helper/framework/app signatures. Current signing is ad-hoc, not notarized; Developer ID/notarization and Gatekeeper tests are recommended for public delivery.
3. Package only `UsageTopbar.app` using `ditto -c -k --keepParent`, named `UsageTopbar-<version>-macOS-arm64.zip`. Run `python3 scripts/sign-update.py <ZIP> --version <version> --build <build>`. Default mode checks project identity, exact version/build, public key, feed and security settings without using the Keychain. Explicit `--sign` invokes official `sign_update` with the dedicated account and never exports secrets.
4. Put validated final ZIPs in a dedicated release directory. Resolve `SPARKLE=$(scripts/fetch-sparkle.sh)` and run `"$SPARKLE/bin/generate_appcast" --account ALEXESLAT.usage-topbar --maximum-deltas 0 --download-url-prefix https://github.com/ALEXESLAT/usage-topbar/releases/download/v<VERSION>/ <release-directory>`. This signs archives and feed. Do not supply private-key arguments, environment secrets or CI secrets. The maintainer handles any local Keychain prompt without bypassing access controls. Never edit signed files afterwards.
5. Test first. After release approval, upload the final ZIP, download and verify it, then publish the matching signed `updates/appcast.xml` in this repository. Its fixed HTTPS feed URL is `https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml`. Keep a verified previous release for explicit recovery.
6. Verify discovery, download, install, relaunch and process cleanup from an installed updater-enabled app. A working download page or SHA-256 match alone does not verify upgrading.

## Security and privacy

Signed feeds and archive verification before extraction are mandatory, with no expiry-based signature fallback. Production requires the project's HTTPS Release URL and increasing integer builds. The pre-signing gate supplements cryptographic authenticity with exact package identity/version checks. Authentic signatures do not prove freshness; old valid feeds may freeze updates or offer a non-latest build still newer than the installed app.

No automatic updates, profiling, JavaScript or remote release notes. Manual requests disclose normal connection/HTTP metadata to GitHub/CDN, potentially including client/system versions. No Codex account, quota, card or credential fields are attached. No screen permission, system security or login-item changes. Non-writable destinations may require system authorization.

Key loss can require manual reinstallation; compromise permits forged updates. Backup export was not authorized or performed. Any future backup needs a separately approved encrypted offline destination, never the repository or chat.

## Evidence and limits

The isolated host used a distinct Bundle ID, loopback HTTP, real signed feeds/ZIPs and Sparkle's installer. Of 15 scenarios, 13 met expectations: 21→22 replacement/relaunch, no update, tampered feed/archive, actual downgrade rejection, check/offer/download/ready-to-install cancellation, feed/download 404, interrupted download, and missing installer helper. Failed/cancelled cases retained the old app; owned test children were cleaned up.

Two did not: a trusted-signed different Bundle ID and actual build 23 advertised as build 22 were installed. Pre-signing gate tests reject both, but no runtime rejection claim is made.

The loopback URL and programmable test driver are test-host-only, absent from production policy. Public HTTPS/CDN delivery, mid-replacement filesystem failure rollback, updating with a real Codex child, and notarized behavior remain unverified. The lifecycle fixture used its own sleep child, not Codex. Automatic crash rollback is not implemented or promised.

Official references: [Integration](https://sparkle-project.org/documentation/programmatic-setup/), [security](https://sparkle-project.org/documentation/customization/), [publishing](https://sparkle-project.org/documentation/publishing/).

## Supported hooks and threat boundary

Sparkle 2.10.0 public SPUUpdaterDelegate was inspected: shouldProceedWithUpdate receives feed metadata before download; didExtractUpdate / willInstallUpdate are notifications without an extracted-bundle path or rejection return. Postponing relaunch is not a validation hook. No supported hook was found for exact extracted Bundle ID/feed-version matching. No private cache paths/APIs or custom replacement implementation were used.

Unsigned tampering was rejected. The mismatches require the trusted signer to sign wrong content. Preflight reduces accidental signing; compromised private keys grant update authority and can sign malicious code with the correct ID too. Developer ID must not be assumed to fix exact matching without testing.

If independent runtime exact identity/version rejection is mandatory, the smallest conservative alternative is to withhold one-click replacement and offer version notices and official downloads for manual installation. This fallback was not silently substituted. Automatic replacement with that requirement needs upstream support or a separately reviewed maintained framework change. Official release remains paused.

Pinned sources: [delegate](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SPUUpdaterDelegate.h), [bundle selection](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUInstaller.m), [actual downgrade prevention](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUPlainInstaller.m).

## Settings across upgrades

Starting in 0.5.0, the explicit overlay visibility choice is persisted as `overlay.userHidden` in the stable `local.alex.usage-topbar` preferences domain. Missing preferences, including upgrades from 0.4.0, default to visible. Automatic occlusion is transient; demo mode never writes this preference. Position, appearance and dimensions are computed rather than user settings. Keep the bundle ID and key stable; no settings file needs packaging or migration.

macOS ServiceManagement owns login-item state; updating does not register or unregister it. Login after a real upgrade still requires separate verification. The app owns no account configuration or credential store; it invokes the local Codex app-server using the existing login without copying or changing credentials. Sparkle preferences share the app domain; automatic checks, downloads and system profiling are intentionally forced off at startup.

Exact runtime bundle ID/feed-build matching was an extra acceptance condition, not a user requirement or evidence of an attack without the trusted signing key. Preserve those failed assertions as publisher-mistake limitations. Continue informed ad-hoc testing; prefer Developer ID, notarization and real-download validation for general distribution.

Settings integration: using the production OverlayPreferences code and isolated preference domains, both hidden and shown choices plus an unrelated sentinel survived real Sparkle 21→22 replacement and relaunch. All four attempts ultimately succeeded. Early runner snapshots timed out before completion; those records are retained, and the runner now waits up to 180 seconds for the new host to exit. This uses a separate host and settings probe, not the full production AppDelegate UI. Read-only before/after checks confirmed the installed version, executable, preference-file presence and login-item status were unchanged.

## Actual-app standard UI validation

Subsequent testing used the real AppDelegate, RateLimitClient, preferences and Sparkle standard UI for a local 21-to-22 download, install and relaunch. Display versions 0.5.0 to 0.5.1 were isolated tests, not releases. Only bundle identity/name, loopback update origin/policy and the synthetic app-server path changed in the test copy; production has no such exceptions. Native Accessibility actions used existing permission, with no custom Sparkle user driver.

Observed: no startup update request; check cancellation; no-update; feed 404; invalid signature; skip version; download cancellation; archive 404; Install and Relaunch. The new app restored hidden preferences and its menu toggled the stored value correctly. The actual AppDelegate cleaned up the synthetic app-server on upgrade and normal quit. The installer spent minutes in a replacement call before completing without intervention; final metadata, signatures and a new process established success. Production installation and login-item state were unchanged.

This supplements the earlier separate-host tests, not real credentials/OpenAI requests, every UI branch, or a Mac login/logout/reboot. Public HTTPS/CDN, Developer ID/notarization and quarantined downloads remain unverified. No remote test Release or appcast was uploaded.
