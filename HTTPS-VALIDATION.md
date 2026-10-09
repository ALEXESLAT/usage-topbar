# HTTPS updater validation prerelease

This branch and its v0.5.0-updater-test.1 release are isolated tests, not the next stable UsageTopbar release. Stable remains v0.4.0. The test app has bundle ID `local.alex.usage-topbar.https-test`, uses synthetic account data only, and reads a separately signed test-branch appcast. It does not use real Codex credentials or register a login item automatically. Do not replace the stable app with this test app; use a separate folder.

The archive is ad-hoc signed, not Developer ID signed or notarized. No Gatekeeper bypass is part of these instructions. If macOS blocks the app, stop and report it. Successful testing on the maintainer Mac does not guarantee a clean Mac will accept it.

This public branch includes the pending updater implementation plus these explicit test-only isolation changes. Main and its update channel are unchanged. The Ed25519 verification public key is public; the private key remains in the maintainer Keychain and is never included.

Only the ZIP, SHA-256 checksums and detached public signature metadata belong in the prerelease assets. No logs, local evidence, private paths, credential material or personal account values belong here. Synthetic 60% remaining usage is fixed fixture data.
