# Signed update feed staging

No live appcast is published. The dedicated Ed25519 key was created with explicit approval; only `app/update-public-key.txt` is in source. Never regenerate or rotate it as a routine release step.

See [maintainer release and user update steps](../docs/UPDATES.en.md) / [中文](../docs/UPDATES.md).

Validate identity and exact build/version with `scripts/sign-update.py` before signing. Publish verified release ZIP assets first, then the appcast signed by Sparkle's `generate_appcast` with account `ALEXESLAT.usage-topbar`. An arbitrary GitHub Release alone does not enable updates. Official publication still requires authorization.
