# Local data contract

The overlay uses the Codex app-server JSONL protocol:

- Request: `account/rateLimits/read`
- Update notification: `account/rateLimits/updated`
- Fields rendered: `primary.usedPercent`, `secondary.usedPercent`, window durations, reset timestamps, and `credits.balance`.

Remaining percentage is calculated as `100 - usedPercent`. The bar uses the most constrained available window so it never overstates usable capacity.

GPT connectivity combines event-driven local network-path status, successful or failed responses to the existing 30-second rate-limit read, and a bodyless, credential-free TLS handshake to `chatgpt.com:443`. The handshake runs every five seconds on external power or fifteen seconds on battery/Low Power Mode and fails after two seconds.

For live throughput, the companion reads cumulative byte counters from active external interfaces and converts deltas into bytes per second. The displayed `NET` value is whole-Mac throughput, not Codex-exclusive traffic. Sampling is every two seconds on external power and every five seconds on battery or in Low Power Mode. It does not inspect endpoints or traffic contents.

For contrast adaptation, the companion uses ScreenCaptureKit to sample a 12×12 px region from the ChatGPT title bar and calculates only its average luminance. It does not perform OCR or request Screen Recording permission automatically. If permission is unavailable, it silently uses the system light/dark appearance instead.

The companion process keeps responses in memory only. It does not write snapshots, credentials, credit balances, interface statistics, window geometry, color samples, or screenshots to disk.
