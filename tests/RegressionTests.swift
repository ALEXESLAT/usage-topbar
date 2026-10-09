setbuf(stdout, nil)
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let parser = RateLimitClient(monitorsPath: false)
let now = Date().timeIntervalSince1970
func window(_ used: Any, _ mins: Int = 300, _ reset: Double = Date().timeIntervalSince1970 + 3600) -> [String: Any] {
    ["usedPercent": used, "windowDurationMins": mins, "resetsAt": reset]
}
func read(_ limits: [String: Any]) -> UsageSnapshot? { parser.parseReadResponse(["rateLimits": limits]) }
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
check(constrained.detail.hasPrefix("7 days"), "duration is actual window")
check(constrained.resetText == "2d", "reset belongs to constrained window")
check(read(["primary": window(25)])?.detail.hasPrefix("5 hrs") == true, "five hour label")
check(read([:]) == nil, "missing usage is unknown")
check(read(["primary": window(10), "credits": ["balance": "NaN"]])?.detail.contains("points --") == true, "invalid credits")
check(parser.parseReadResponse(["rateLimitsByLimitId": ["codex": ["primary": window(75)], "other": ["primary": window(1)]]])?.remaining == 25, "codex bucket wins")
print("PASS: 17 quota/unknown/bounds/duration/bucket assertions")

let primary = CGRect(x: 0, y: 0, width: 1440, height: 875)
let upper = CGRect(x: 0, y: 900, width: 1920, height: 1050)
let left = CGRect(x: -1280, y: 0, width: 1280, height: 1000)
let ordinary = CGRect(x: 100, y: 100, width: 800, height: 600)
check(OverlayPlacement.frame(window: ordinary, visibleScreens: [primary], scale: 2) == CGRect(x: 100, y: 678, width: 328, height: 74), "normal attachment")
check(OverlayPlacement.frame(window: CGRect(x: 100, y: 1100, width: 1000, height: 600), visibleScreens: [primary, upper], scale: 1)?.minY == 1678, "vertically stacked display")
check(OverlayPlacement.frame(window: CGRect(x: -1200, y: 100, width: 800, height: 600), visibleScreens: [primary, left], scale: 1)?.minX == -1200, "negative origin display")
check(OverlayPlacement.frame(window: CGRect(x: 1400, y: 100, width: 500, height: 500), visibleScreens: [primary], scale: 2)?.maxX == 1440, "right edge clamp")
check(OverlayPlacement.frame(window: CGRect(x: 0, y: 0, width: 1440, height: 875), visibleScreens: [primary], scale: 2) == nil, "maximized/no top room hides overlay")
check(OverlayPlacement.frame(window: ordinary, visibleScreens: [], scale: 1) == nil, "display removed")
check(OverlayPlacement.frame(window: ordinary, visibleScreens: [CGRect(x: 0, y: 0, width: 300, height: 1000)], scale: 1) == nil, "insufficient width")
let fractional = OverlayPlacement.frame(window: CGRect(x: 100.2, y: 100.2, width: 800, height: 600), visibleScreens: [primary], scale: 2)!
check(fractional.minX * 2 == (fractional.minX * 2).rounded(), "Retina pixel alignment")
print("PASS: 8 display geometry assertions")

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
