# Signed production update feed

`appcast.xml` is the signed manual-update feed for the production app. Publish and verify the referenced immutable Release ZIP before enabling this feed. Both archive and feed signatures and exact metadata must pass `scripts/verify-update-release.py` before publication and again on downloaded files with saved hashes.

Only `app/update-public-key.txt` is public. The private key remains in the approved maintainer Keychain account; do not generate, export, rotate or upload it as a routine release step. Test releases remain on their own branch. See [English](../docs/UPDATES.en.md) / [中文](../docs/UPDATES.md).
