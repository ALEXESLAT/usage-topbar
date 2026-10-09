# Local data contract

This contract describes 0.4.0 (20), Apple Silicon / macOS 13+. The overlay uses the Codex app-server JSONL protocol:

- Request: `account/rateLimits/read`
- Periodic reads are authoritative; unsolicited update notifications cannot replace the selected bucket or satisfy a pending read.
- Fields rendered: `primary.usedPercent`, `secondary.usedPercent`, window durations, reset timestamps, `credits.balance`, and `rateLimitResetCredits` count/expiry details.

Only the `codex` bucket or compatible legacy default is accepted; unrelated model buckets are never substituted. Remaining percentage is calculated as `100 - usedPercent`. The bar uses the most constrained available window with its actual duration and matching reset time. Missing/invalid responses and connection failures render `--%`, not zero. Values must be finite and percentages are clamped to 0–100.

Codex connectivity is driven by the authenticated 30-second rate-limit read. Green means the latest valid request succeeded, yellow means the app is checking, and red means the request failed or the local network path is unavailable. Generic internet or TLS reachability cannot set the indicator to green.

For live throughput, the companion reads cumulative byte counters from active external interfaces and converts deltas into bytes per second. The download/upload values below the card details are whole-Mac throughput, not Codex-exclusive traffic and not part of the connection decision. Sampling is every two seconds on external power and every five seconds on battery or in Low Power Mode. It does not inspect endpoints or traffic contents.

For contrast adaptation, the companion uses ScreenCaptureKit to sample a 12×12 point region from the Codex/ChatGPT title bar on macOS 14+ with existing permission, at most about every three seconds and calculates only its average luminance. It does not perform OCR or request Screen Recording permission automatically. If permission is unavailable, it silently uses the system light/dark appearance instead.

Throughput uses actual elapsed time and per-interface baselines; newly appearing interfaces, counter rollover, and long sampling gaps do not produce artificial spikes. Sleep stops monitoring; wake reconnects and obtains fresh data.

The companion process keeps responses in memory only. It does not write snapshots, credentials, credit balances, interface statistics, window geometry, color samples, or screenshots to disk.

The release begins this monitoring on launch without a repeated dialog. Reset-card count and expiry details are included in the existing authenticated read; it never consumes a reset credit. Window tracking uses 0.2-second checks for the foreground target (including automatic hiding) and one-second checks in the background or when manually hidden, with activation/display/wake event checks. No login item is registered automatically, and no new credentials/permissions are created. Quitting stops timers and requests and terminates only this app’s own app-server child.

Launch at login is an optional menu setting, off by default. Only a user click registers or unregisters SMAppService.mainApp. Read the actual service status; do not enable it or approve system prompts on the user’s behalf.
