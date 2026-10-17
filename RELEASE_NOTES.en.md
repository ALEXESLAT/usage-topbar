# Usage Topbar 0.7.0

[简体中文](RELEASE_NOTES.md)

**Release · build 52 · Apple Silicon · macOS 13+**

0.7.0 brings local quota history and custom gradients to the release configuration while retaining manual updates and a separate Testing channel.

- **Browse history:** left-click the menu-bar percentage for a four-day preview, then click the chart for a horizontally scrollable seven-day window. Detail uses crosshair readings; the compact view keeps hover labels concise.
- **Edit colors:** right-click the status item → **渐变设置…** (Gradient settings). Adjust color, alpha and stops; preview, save, cancel or reset. The bar retains its full-track palette and clips from the right. Both history views map the same palette vertically to quota values.
- **Keep real records:** fresh readings are normally recorded every 30 minutes, with additional lifecycle/event samples, and retained for three rolling months. Long gaps and reset boundaries do not invent missing data. Some resets are inferred; offline events cannot always be classified.
- **Appearance:** follows the effective light/dark appearance, with Liquid Glass on macOS 26+ and materials on earlier supported systems. History uses blur and adaptive background tint.
- **Reduce repeated work:** cache curve/gradient rendering, pause hidden-chart refreshes and catch up when shown. History snapshots save serially in the background, coalesce changes, retry failures and flush on sleep/exit.
- **Retain settings on upgrade:** preserve the production preference domain and saved palette. Real-history migration validates, deduplicates, favors production conflicts and provides backups/rollback. Testing preferences and simulated data are not imported.

Users of 0.5.0 or later production versions can choose “检查更新…” (Check for Updates) and approve download, installation and relaunch. Version text and notes come from a matching authenticated feed item; missing or inconsistent metadata produces an unavailable message instead of old notes.

CI and package signature verification passed. Some foreground interaction checks and resource sampling remain incomplete. No claim of complete validation or improved battery life is made. The app is ad-hoc signed, not Apple-notarized, and has no automatic health rollback. Older macOS and physical-trackpad coverage remain limited.
