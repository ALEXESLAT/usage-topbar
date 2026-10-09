setbuf(stdout, nil)
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let parser = RateLimitClient(monitorsPath: false)
let now = Date().timeIntervalSince1970
func window(_ used: Any, _ mins: Int = 300, _ reset: Double = Date().timeIntervalSince1970 + 3600) -> [String: Any] {
    ["usedPercent": used, "windowDurationMins": mins, "resetsAt": reset]
}
func read(_ limits: [String: Any]) -> UsageSnapshot? { parser.parseReadResponse(["rateLimits": limits], now: Date(timeIntervalSince1970: now)) }
check(UsageSnapshot.unavailable("offline").percentageText == "--%", "unknown must not be zero")
check(UsageSnapshot(remaining: 0, detail: "", resetText: nil).percentageText == "0%", "zero remains valid")
check(UsageSnapshot(remaining: 100, detail: "", resetText: nil).percentageText == "100%", "100 label")
check(parser.parseReadResponse(["rateLimitsByLimitId": ["other": ["primary": window(10)]]]) == nil, "foreign bucket rejected")
check(read(["limitId": "other", "primary": window(10)]) == nil, "foreign legacy bucket rejected")
check(read(["primary": window("NaN")]) == nil, "NaN rejected")
check(read(["primary": window(true)]) == nil, "boolean rejected")
check(read(["primary": window(Double.infinity)]) == nil, "infinity rejected")
check(read(["primary": window(-5)])?.remaining == 100, "lower bound clamped")
check(read(["primary": window(150)])?.remaining == 0, "upper bound clamped")
check(read(["primary": window("25")])?.remaining == 75, "numeric string")
let constrained = read(["primary": window(20, 300, now + 600), "secondary": window(85, 10080, now + 172800)])!
check(constrained.remaining == 15, "most constrained remaining")
check(constrained.detail.contains("left") && !constrained.detail.hasPrefix("7 days"), "detail is countdown, not quota window duration")
check(constrained.resetText == "2d", "reset belongs to constrained window without rounding days up")
check(read(["primary": window(25)])?.detail.contains("left") == true, "five hour window uses actual countdown")
check(read([:]) == nil, "missing usage is unknown")
check(read(["primary": window(10), "credits": ["balance": "NaN"]])?.detail.contains("points --") == true, "invalid credits")
check(parser.parseReadResponse(["rateLimitsByLimitId": ["codex": ["primary": window(75)], "other": ["primary": window(1)]]])?.remaining == 25, "codex bucket wins")
print("PASS: 17 quota/unknown/bounds/duration/bucket assertions")


// Fixed-clock countdown regressions: no real account or wall-clock dependence.
let clock = Date(timeIntervalSince1970: 1_791_534_998)
func deadline(_ value: Any, at date: Date = clock) -> UsageSnapshot {
    parser.parseReadResponse(["rateLimits": ["primary": ["usedPercent": 67, "windowDurationMins": 10080, "resetsAt": value], "credits": ["balance": "0"]]], now: date)!
}
check(deadline(clock.timeIntervalSince1970 + 86399).detail.hasPrefix("23h59m left"), "detail keeps minutes while accessory stays compact")
let fiveDays = deadline(clock.timeIntervalSince1970 + 5 * 86400 + 3600)
check(fiveDays.detail == "5d1h left · 0 points" && fiveDays.resetText == "5d1h", "seven day quota with five days remaining")
check(deadline((clock.timeIntervalSince1970 + 432000) * 1000).resetText == "5d", "millisecond normalization")
check(deadline(String(clock.timeIntervalSince1970 + 432000)).resetText == "5d", "numeric timestamp string")
for (seconds, expected) in [(1.0, "<1m"), (59, "<1m"), (60, "1m"), (3599, "59m"), (3600, "1h"), (3660, "1h"), (86399, "23h"), (86400, "1d"), (86401, "1d"), (90000, "1d1h")] {
    check(deadline(clock.timeIntervalSince1970 + seconds).resetText == expected, "countdown boundary \(seconds)")
}
for invalid in [true, "NaN", Double.infinity, -1, 0, 1e20, NSNull()] as [Any] {
    let value = deadline(invalid)
    check(value.resetText == nil && value.detail.hasPrefix("Reset unknown"), "invalid deadline is unknown")
}
for offset in [0.0, -1, -86400] {
    let value = deadline(clock.timeIntervalSince1970 + offset)
    check(value.remaining == nil && value.resetText == "now" && value.detail.hasPrefix("Reset pending"), "expired quota cannot advertise stale percentage")
}
check(fiveDays.refreshed(at: clock.addingTimeInterval(3600)).resetText == "5d", "cached countdown advances without server response")
check(fiveDays.refreshed(at: clock.addingTimeInterval(6 * 86400)).remaining == nil, "cached deadline expires after sleep")
let refreshed = deadline(clock.timeIntervalSince1970 + 7 * 86400, at: clock.addingTimeInterval(6 * 86400))
check(refreshed.remaining == 33 && refreshed.resetText == "1d", "new response restores known quota")
let formatter = ISO8601DateFormatter()
let sameInstant = formatter.date(from: "2030-01-01T08:00:00+08:00")!
check(deadline(1893891600, at: sameInstant).resetText == "5d1h", "UTC+08 deadline uses elapsed time, not calendar-day count")
let paired = parser.parseReadResponse(["rateLimits": ["primary": window(80, 300, clock.timeIntervalSince1970 + 3600), "secondary": window(20, 10080, clock.timeIntervalSince1970 + 432000)]], now: clock)!
check(paired.remaining == 20 && paired.resetText == "1h", "primary constrained percentage and reset stay paired")
check(parser.parseReadResponse(["rateLimits": ["primary": ["usedPercent": 25, "windowDurationMins": 10080]]], now: clock)?.detail.hasPrefix("Reset unknown") == true, "missing deadline stays unknown")
check(paired.detail.contains("7 days quota 80%"), "other window remains explicitly labelled as quota")
print("PASS: fixed-clock reset deadline, units, rounding, invalid/missing, expiry, cache, timezone and paired-window assertions")

let primary = CGRect(x: 0, y: 0, width: 1440, height: 875)
let upper = CGRect(x: 0, y: 900, width: 1920, height: 1050)
let left = CGRect(x: -1280, y: 0, width: 1280, height: 1000)
let ordinary = CGRect(x: 100, y: 100, width: 800, height: 600)
check(OverlayPlacement.frame(window: ordinary, displays: [primary].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 2) }) == CGRect(x: 100, y: 678, width: 308, height: 74), "normal attachment")
check(OverlayPlacement.frame(window: CGRect(x: 100, y: 1100, width: 1000, height: 600), displays: [primary, upper].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 1) })?.minY == 1678, "vertically stacked display")
check(OverlayPlacement.frame(window: CGRect(x: -1200, y: 100, width: 800, height: 600), displays: [primary, left].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 1) })?.minX == -1200, "negative origin display")
check(OverlayPlacement.frame(window: CGRect(x: 1400, y: 100, width: 500, height: 500), displays: [primary].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 2) })?.maxX == 1440, "right edge clamp")
check(OverlayPlacement.frame(window: CGRect(x: 0, y: 0, width: 1440, height: 875), displays: [primary].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 2) }) == nil, "maximized/no top room hides overlay")
check(OverlayPlacement.frame(window: ordinary, displays: [].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 1) }) == nil, "display removed")
check(OverlayPlacement.frame(window: ordinary, displays: [CGRect(x: 0, y: 0, width: 300, height: 1000)].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 1) }) == nil, "insufficient width")
let fractional = OverlayPlacement.frame(window: CGRect(x: 100.2, y: 100.2, width: 800, height: 600), displays: [primary].map { OverlayPlacement.Display(frame: $0, visibleFrame: $0, scale: 2) })!
check(fractional.minX * 2 == (fractional.minX * 2).rounded(), "Retina pixel alignment")
print("PASS: 8 display geometry assertions")

// Mixed-scale ownership must use full bounds, even with a Dock reserving space.
let mixed = [
    OverlayPlacement.Display(frame: CGRect(x: 0, y: 0, width: 1000, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 900, height: 875), scale: 2),
    OverlayPlacement.Display(frame: CGRect(x: 1000, y: 0, width: 1000, height: 900), visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 875), scale: 1)
]
let crossing = OverlayPlacement.frame(window: CGRect(x: 700.2, y: 100.2, width: 580, height: 600), displays: mixed)!
check(crossing.minX == 592 && crossing.minY == 678, "full bounds own screen despite Dock; matching 2x scale")
let moved = OverlayPlacement.frame(window: CGRect(x: 1100.2, y: 100.2, width: 580, height: 600), displays: mixed)!
check(moved.minX == 1100 && moved.minY == 678, "moving to 1x display uses its scale")
let notch = OverlayPlacement.Display(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944), scale: 2)
check(OverlayPlacement.frame(window: CGRect(x: 100, y: 292, width: 800, height: 600), displays: [notch])?.maxY == 944, "exact safe top fits")
check(OverlayPlacement.frame(window: CGRect(x: 100, y: 293, width: 800, height: 600), displays: [notch]) == nil, "notch boundary hides")
let fractionalSafe = OverlayPlacement.Display(frame: primary, visibleFrame: CGRect(x: 0.2, y: 0, width: 1439.6, height: 751.8), scale: 2)
check(OverlayPlacement.frame(window: ordinary, displays: [fractionalSafe]) == nil, "rounding cannot cross safe top")
let edge = OverlayPlacement.frame(window: CGRect(x: -0.1, y: 50, width: 800, height: 600), displays: [fractionalSafe])!
check(edge.minX == 0.5, "left edge rounds inward")
let rightEdge = OverlayPlacement.frame(window: CGRect(x: 1300, y: 50, width: 800, height: 600), displays: [fractionalSafe])!
check(rightEdge.maxX == 1439.5, "right edge rounds inward")
check(OverlayPlacement.appKitBounds(CGRect(x: -1200, y: -800, width: 800, height: 600), primaryTop: 900) == CGRect(x: -1200, y: 1100, width: 800, height: 600), "Quartz above-primary conversion")
check(OverlayPlacement.appKitBounds(CGRect(x: 100, y: 1100, width: 800, height: 600), primaryTop: 900).minY == -800, "Quartz below-primary conversion")
check(OverlayPlacement.frame(window: CGRect(x: 3000, y: 0, width: 800, height: 600), displays: mixed) == nil, "disconnected display window hides")
// Repeated move / resize / reconnect calculations cannot retain stale screen state.
for scale in [CGFloat(1), 1.5, 2, 3] {
    let display = OverlayPlacement.Display(frame: primary, visibleFrame: primary, scale: scale)
    for step in 0..<100 {
        let w = CGRect(x: CGFloat(step) * 12.3 - 100, y: 100.2, width: 800, height: 600)
        if let f = OverlayPlacement.frame(window: w, displays: [display]) {
            check(primary.contains(f), "movement stays within safe frame")
            check(abs(f.minY - (w.maxY - 22)) <= 0.5 / scale + 0.0001, "attachment error below half pixel")
        }
    }
}
check(CodexMark.statusImage.isTemplate && CodexMark.statusImage.size == NSSize(width: 18, height: 18), "Codex menu mark template and size")
check(CodexMark.statusImage.accessibilityDescription == "Codex", "Codex menu mark accessibility")
check(CodexMark.outline.boundingBoxOfPath == CGRect(x: 2, y: 2, width: 20, height: 20), "Codex source viewBox bounds")
check(CodexMark.outline.contains(CGPoint(x: 12, y: 2.5)), "Codex outer ring filled")
check(!CodexMark.outline.contains(CGPoint(x: 12, y: 7)), "Codex inner ring transparent")
check(CodexMark.outline.contains(CGPoint(x: 14, y: 14.5)), "Codex underscore filled")
print("PASS: mixed scales, Dock/notch, rounding, coordinate conversion and 400 movement fixtures")

let before = ["en0": NetworkBytes(received: 100, sent: 200)]
let after = ["en0": NetworkBytes(received: 300, sent: 300)]
let rate = NetworkRateCalculator.rates(previous: before, current: after, elapsed: 4, maximumGap: 6)
check(rate.0 == 50 && rate.1 == 25, "actual elapsed sampling")
check(NetworkRateCalculator.rates(previous: before, current: after, elapsed: 100, maximumGap: 6).0 == 0, "sleep gap")
check(NetworkRateCalculator.rates(previous: after, current: before, elapsed: 2, maximumGap: 6).0 == 0, "counter rollover")
check(NetworkRateCalculator.rates(previous: before, current: ["en1": NetworkBytes(received: 9999999, sent: 0)], elapsed: 2, maximumGap: 6).0 == 0, "new interface baseline")
print("PASS: 4 throughput assertions")

func exercise(_ name: String, duration: TimeInterval = 2.5) -> (Int, [String]) {
    let executable = CommandLine.arguments[1] + "/" + name
    let client = RateLimitClient(executable: executable, timeout: 1.5, retryDelays: [0.06, 0.12, 0.2], monitorsPath: false)
    var samples = 0
    var statuses: [String] = []
    client.onSnapshot = { snapshot in
        check(snapshot.remaining == 60, "only the matching request may update usage")
        samples += 1
    }
    client.onStatus = { statuses.append($0) }
    client.start()
    // Repeated refreshes must not postpone initialization/request deadlines.
    for _ in 0..<5 { client.refresh() }
    RunLoop.current.run(until: Date().addingTimeInterval(duration))
    client.stop()
    let stopped = samples
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
    check(samples == stopped, "stop cancels restart and late callbacks")
    print("Scenario \(name): samples=\(samples), statuses=\(statuses)")
    return (samples, statuses)
}
let recovery = exercise("recover", duration: 4.0)
check(recovery.0 >= 2, "recover from child exit and partial response")
let hung = exercise("hang", duration: 4.5)
check(hung.0 == 0 && hung.1.filter { $0.contains("timed out") }.count >= 2, "initialization timeout and retry")
let stalledRead = exercise("stall")
check(stalledRead.0 == 0 && stalledRead.1.contains(where: { $0.contains("timed out") }), "read timeout and retry")
let foreign = exercise("foreign")
check(foreign.0 == 0 && foreign.1.contains("Usage unavailable"), "foreign live bucket invalidates usage")
let rejected = exercise("error")
check(rejected.0 == 0 && rejected.1.contains("Codex request failed"), "explicit errors invalidate usage")
let bounded = exercise("oversized")
check(bounded.0 == 0 && bounded.1.contains(where: { $0.contains("Invalid response") }), "bounded response buffer")
let restartable = RateLimitClient(executable: CommandLine.arguments[1] + "/recover", timeout: 1.5, retryDelays: [0.1], monitorsPath: false)
var restartedSamples = 0
restartable.onSnapshot = { _ in restartedSamples += 1 }
restartable.start()
RunLoop.current.run(until: Date().addingTimeInterval(1.0))
restartable.stop()
let beforeWake = restartedSamples
restartable.start()
RunLoop.current.run(until: Date().addingTimeInterval(1.0))
restartable.stop()
check(restartedSamples > beforeWake, "sleep/wake stop/start is reusable")
print("PASS: 7 credential-free app-server lifecycle scenarios")

// Reset cards use their own official summary; quota resets and credit balance are unrelated.
let cardNow = Date(timeIntervalSince1970: 1893456000)
let china = TimeZone(secondsFromGMT: 8 * 3600)!
func card(_ id: String, _ expiry: Any = NSNull(), _ status: String = "available", _ type: String = "codexRateLimits") -> [String: Any] {
    ["id": id, "expiresAt": expiry, "status": status, "resetType": type]
}
func cards(_ count: Any, _ rows: Any = NSNull()) -> ResetCards? {
    ResetCards.parse(["availableCount": count, "credits": rows])
}
check(ResetCards.parse(nil) == nil && ResetCards.parse(NSNull()) == nil, "absent cards unknown, not zero")
for invalid in [true, -1, 1.5, "3", Double.infinity] as [Any] { check(cards(invalid) == nil, "invalid card count unknown") }
check(cards(0, [])!.display(at: cardNow).count == 0, "zero explicitly returned")
let syntheticCardFixture = cards(3, [card("a", 1894305600), card("b", 1895169600), card("c", 1896033600)])!
let syntheticCardDisplay = syntheticCardFixture.display(at: cardNow, timeZone: china)
check(syntheticCardDisplay.count == 3 && syntheticCardDisplay.expiryText == "Exp. 01/11", "synthetic response count and earliest expiry")
check(syntheticCardDisplay.accessibilityText.contains("2030-01-11 04:00:00 +08:00"), "complete expiry includes year seconds timezone")
check(syntheticCardFixture.display(at: cardNow, timeZone: TimeZone(secondsFromGMT: 0)!).expiryText == "Exp. 01/10", "timezone changes wall date, not instant")
check(cards(1, [card("one", 1894305600)])!.display(at: cardNow, timeZone: china).expiryText == "Exp. 01/11", "one card")
check(cards(3)!.display(at: cardNow).count == 3 && cards(3)!.display(at: cardNow).expiryText == "Exp. --", "count known but missing details")
check(cards(3, [card("one", 1894305600)])!.display(at: cardNow).expiryText == "Exp. --", "capped list cannot establish earliest expiry")
check(cards(1, [card("forever")])!.display(at: cardNow).expiryText == "Exp. none", "explicit null is nonexpiring")
check(cards(1, [["id": "missing", "status": "available", "resetType": "codexRateLimits"]])!.display(at: cardNow).expiryText == "Exp. --", "missing expiry is not nonexpiring")
check(cards(1, [card("millis", 1894305600000)])!.display(at: cardNow).expiryText == "Exp. --", "card protocol seconds, malformed unit rejected")
check(cards(2, [card("same", 1894305600), card("same", 1894305600)])!.display(at: cardNow).expiryText == "Exp. --", "duplicate details cannot fabricate completeness")
check(cards(1, [card("used", 1894305600, "redeemed")])!.display(at: cardNow).expiryText == "Exp. --", "redeemed not treated as available expiry")
check(cards(1, [card("other", 1894305600, "available", "unknown")])!.display(at: cardNow).expiryText == "Exp. --", "unknown reset type not treated as Codex expiry")
let expired = syntheticCardFixture.display(at: Date(timeIntervalSince1970: 1894305600), timeZone: china)
check(expired.count == 2 && expired.expiryText == "Exp. 01/21", "exact expiry boundary excludes first card")
check(syntheticCardFixture.display(at: Date(timeIntervalSince1970: 1896033600)).count == 0, "all expired complete snapshot")
check(cards(3, [card("old", 1)])!.display(at: cardNow).count == nil, "partial expired snapshot invalidates stale count")
let parsedCards = parser.parseReadResponse(["rateLimits": ["primary": window(69, 10080, 1893891600)], "rateLimitResetCredits": ["availableCount": 3, "credits": [card("a", 1894305600), card("b", 1895169600), card("c", 1896033600)]]], now: cardNow)!
check(parsedCards.resetCardDisplay.count == 3 && parsedCards.resetsAt == 1893891600, "cards and quota deadlines stay separate")
check(parsedCards.refreshed(at: Date(timeIntervalSince1970: 1894305600)).resetCardDisplay.count == 2, "cached cards refresh even after quota expired")
let nextResponse = parser.parseReadResponse(["rateLimits": ["primary": window(69)], "rateLimitResetCredits": ["availableCount": 1, "credits": [card("new", 1895169600)]]], now: cardNow)!
check(nextResponse.resetCardDisplay.count == 1, "fresh summary replaces cached card count")
check(UsageSnapshot.unavailable("offline").resetCardDisplay.count == nil, "offline clears stale card display")
check(cards(1000)!.display(at: cardNow).countText == "99+", "large count keeps fixed compact width")
print("PASS: reset card 0/1/many, missing/partial, expiry, no-expiry, invalid data, timezone, refresh and source separation")

// System-font metrics are checked against the actual fixed numeric columns.
let quotaFont = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
for percent in 0...100 {
    check(("\(percent)%" as NSString).size(withAttributes: [.font: quotaFont]).width <= OverlayDimensions.quotaWidth, "quota column fits \(percent)%")
}
let digitWidths = (0...9).map { ("\($0)" as NSString).size(withAttributes: [.font: quotaFont]).width }
check((digitWidths.max() ?? 0) - (digitWidths.min() ?? 0) < 0.001, "system tabular digits do not jitter")
let smallFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
let expiryFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
for expiry in ["Exp. 12/31", "Exp. none", "Exp. --"] {
    check((expiry as NSString).size(withAttributes: [.font: expiryFont]).width + 16 + 4 + 6 + ("99+" as NSString).size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)]).width <= 104, "largest card and expiry row fits accessory")
}
for (bytes, label) in [(0.0, "0B"), (999.4, "999B"), (1023, "1K"), (1024, "1K"), (1048576, "1M"), (1073741824, "1G"), (1e30, "999T+")] {
    check(OverlayLabels.rate(bytes) == label, "compact throughput units")
    check(("↓" + label as NSString).size(withAttributes: [.font: smallFont]).width <= 43, "long throughput fits fixed column")
}
check(OverlayLabels.rate(Double.nan) == "--", "invalid throughput unknown")
check(OverlayLabels.points(UsageSnapshot(remaining: 22, detail: "5d left · 1000000k points", resetText: "5d")) == "1B pts", "long point amount compacted")
check(OverlayLabels.points(.unavailable("offline")) == "-- pts", "missing points stay unknown")
print("PASS: system-font metrics, tabular digits, 0...100%, long throughput/points and missing data")

// Display deduplication retains raw state and accessibility while avoiding equivalent redraws.
let displayModel = OverlayModel()
var invalidations = 0
let observation = displayModel.objectWillChange.sink { invalidations += 1 }
displayModel.updateRates(download: 10_240, upload: 5_120)
check(invalidations == 1, "both changed rate labels publish once")
displayModel.updateRates(download: 10_241, upload: 5_121)
check(invalidations == 1, "same displayed rates do not publish")
check(displayModel.downloadBytesPerSecond == 10_241 && displayModel.uploadBytesPerSecond == 5_121, "raw rates remain current")
displayModel.updateRates(download: 20_480, upload: 5_121)
check(invalidations == 2, "changed rate label publishes")
displayModel.connectionState = .connected
displayModel.connectionState = .connected
check(invalidations == 3, "duplicate connectivity does not publish")
displayModel.isDarkBackground = false
displayModel.isDarkBackground = false
check(invalidations == 4, "duplicate appearance does not publish")
var displaySnapshot = UsageSnapshot(remaining: 7, detail: "5d left · 0 points", resetText: "5d", resetsAt: 1000, resetDetailSuffix: "0 points")
displayModel.snapshot = displaySnapshot
let snapshotInvalidations = invalidations
displaySnapshot.resetsAt = 1001
displayModel.snapshot = displaySnapshot
check(invalidations == snapshotInvalidations && displayModel.snapshot.resetsAt == 1001, "same presentation retains newer raw deadline without redraw")
displaySnapshot.remaining = 7.1
displayModel.snapshot = displaySnapshot
check(invalidations == snapshotInvalidations + 1, "fractional progress change is not dropped")
displaySnapshot.detail = "5d left · 1 points"
displayModel.snapshot = displaySnapshot
check(invalidations == snapshotInvalidations + 2, "points and accessibility update")
displaySnapshot.resetCardDisplay = ResetCardDisplay(count: 3, expiryText: "Exp. 01/11", accessibilityText: "Exact expiry changed")
displayModel.snapshot = displaySnapshot
check(invalidations == snapshotInvalidations + 3, "card accessibility changes are not dropped")
var measurements = 0
let metrics = QuotaTextMetricsCache { percentage, points in
    measurements += 1
    return QuotaTextMetricsCache.measureInset(percentage, points)
}
for _ in 0..<100 { _ = metrics.inset(percentage: "7%", points: "0 pts") }
check(measurements == 1, "identical quota strings reuse glyph measurement")
for percentage in ["12%", "100%", "7%"] {
    let cached = metrics.inset(percentage: percentage, points: "0 pts")
    check(cached == QuotaTextMetricsCache.measureInset(percentage, "0 pts"), "cache preserves glyph alignment")
}
check(measurements == 4, "cache refreshes on percentage changes")
_ = metrics.inset(percentage: "7%", points: "999.9k pts")
check(measurements == 5, "cache refreshes on points changes")
check(OverlayTrackingPolicy.interval(targetActive: true, userHidden: false, sleeping: false) == 0.2, "active tracking remains responsive")
check(OverlayTrackingPolicy.interval(targetActive: false, userHidden: false, sleeping: false) == 1, "background uses fallback cadence")
check(OverlayTrackingPolicy.interval(targetActive: true, userHidden: true, sleeping: false) == 1, "manual hiding uses fallback cadence")
check(OverlayTrackingPolicy.interval(targetActive: true, userHidden: false, sleeping: true) == nil, "sleep stops tracking")
print("PASS: display-label dedup, raw retention, accessibility/progress changes, bounded glyph cache and tracking policy")
