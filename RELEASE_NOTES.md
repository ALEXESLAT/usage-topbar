# Usage Topbar 0.2.5

Usage Topbar 0.2.5 build 16 adds the approved minimal usage-bars icon, refines the native Liquid Glass treatment, and retains the GPT connectivity indicator.

> **AI-generated software:** This program and its documentation were written by artificial intelligence.
>
> **AI 生成声明：** 本程序及其文档由人工智能编写。

## Highlights

- Green, yellow, and red GPT network states using local path events, the existing 30-second usage request, and a lightweight OpenAI TLS handshake
- Faster OpenAI-specific failure detection using a two-second TLS timeout and adaptive five/fifteen-second handshake cadence
- Compact whole-Mac `NET` download/upload rates from low-overhead interface counters (two seconds on external power, five seconds on battery/Low Power Mode)
- Compact 328×52 pt information area with symmetric continuous top corners
- A 22 pt rounded underlap sits behind the Codex window
- The left edge remains vertical for 12 pt below the meeting line before the 10 pt lower corner begins
- Appears only while Codex is the foreground application
- Orders directly below the tracked Codex window instead of forcing itself above other apps
- No rectangular NSPanel shadow or duplicate SwiftUI drop shadow
- SwiftUI implementation using official `glassEffect(.regular)` on macOS 26
- Clearer native refraction with the extra dark backing removed, a lighter adaptive tint, and an adaptive hairline border
- Minimal usage-bars application icon with a compact connection-state accent
- Larger percentage and detail typography with a compact two-line hierarchy
- Integrated remaining-usage track and seamless window attachment
- Window duration, points balance, and next reset information
- Automatic dark/light text based on local background luminance
- Rounded SF system typography and concise English labels
- Menu-bar refresh, visibility, and quit controls
- Privacy-gated live mode with no usage or screen sample persistence

## Package

`UsageTopbar-0.2.5-macOS-arm64.zip` contains the ad-hoc signed Apple Silicon macOS application.
