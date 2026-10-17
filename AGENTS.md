# UsageTopbar project rules

- Release/version facts and update descriptions must come from the authenticated appcast item that matches the target build, marketing version and asset URL. Never hardcode release-specific facts into application UI. Generic action labels may remain static.
- Missing or inconsistent metadata must say it was not obtained; never substitute old notes or claim success. Download, installation, cancellation and completion must reflect actual updater callbacks.
- Keep release notes embedded in the signed feed; do not fetch unbound remote text or cache another version's description. Validate multiple versions, missing metadata and cancel/retry.
- Test the exact release configuration and packaged binary. Testing or fixture evidence does not establish production UI acceptance. Preserve installed apps and real data during isolated acceptance.
- A draft is not a release. Do not publish or switch the main feed while a required gate is unresolved.
