# Strict update validation

Upstream Sparkle 2.10.0 source commit: `eef1a539a373c1f1a320624b1130fc5de7b2e100`.
Source tarball SHA-256: `fd2a5de329be3619111f9a73a1adeac9725a92292f0431c93679e5e2b0d48a04`.

The public updater delegate does not expose an extracted archive path and veto hook. This additive source patch uses Sparkle's existing `SUUpdateValidator.validateWithUpdateDirectory` path (before either signature-validation branch) in the installer. Hosts opting in via the bundled `UsageTopbarStrictUpdateValidation` boolean reject missing/different Bundle IDs and missing/non-string/different CFBundleVersion values compared with the authenticated appcast's expectedVersion. It does not replace signature verification or installation handling.

`scripts/harden-sparkle.py` verifies pinned source bytes, applies this patch, builds the upstream Sparkle scheme for arm64, and ad-hoc signs the nested framework. It retains official signing tools from the separately hash-verified upstream SDK. Source, patch, builder and Xcode version key the local cache. The framework marker and host opt-in are required by release preflight. No private key is needed to build the framework.

Protection runs in the currently installed updater. Older installed versions use their original updater until the first successful upgrade; publisher-side exact identity/version/signature checks remain mandatory for that transition. The integration harness tests both the strict path and a legacy-to-patched transition, never the user's installed app.

Upstream source and framework retain Sparkle's MIT license (included in the distributed app). Patch additions are under this repository's MIT license.
