func require(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }
var fill = RecoveryFill()
fill.receive(nil, at: 0, animate: true); require(fill.frame(at: 0).value == nil, "unknown fabricated")
fill.receive(97, at: 1, animate: true)
for i in 0...48 {
    let t = Double(i)/60, f = fill.frame(at: 1+t)
    let expected = t >= 0.8 ? 97 : 97 * (1-pow(1-t/0.8,2))
    require(abs(f.value! - expected) < 0.00001, "digit/bar scalar curve mismatch")
    require(RecoveryFill.text(f.value, animating: f.animating) != "100%", "false full quota")
}
fill.receive(97, at: 1.2, animate: true); require(fill.frame(at: 1.2).animating, "duplicate restarted/stopped animation")
let beforeRetarget = fill.frame(at: 1.3).value!
fill.receive(12, at: 1.3, animate: true); require(fill.frame(at: 1.3).value == beforeRetarget, "retarget jumps")
require(fill.frame(at: 1.801).value == 12 && !fill.frame(at: 1.801).animating, "latest real target not reached on deadline")
fill.receive(13, at: 2, animate: true); require(!fill.frame(at: 2).animating, "routine refresh replays")
for cycle in 0..<3 {
    let t = Double(cycle+3)
    fill.receive(nil, at: t, animate: true); require(fill.frame(at: t).value == nil, "offline should be unknown")
    fill.receive(nil, at: t+0.1, animate: true)
    fill.receive(100, at: t+0.2, animate: true); require(fill.frame(at: t+0.2).value == 0, "recovery should start zero")
    fill.receive(100, at: t+0.3, animate: true)
    require(fill.frame(at: t+1.001).value == 100 && !fill.frame(at: t+1.001).animating, "recovery repeated/failed")
}
fill.receive(nil, at: 10, animate: true);fill.receive(0, at: 11, animate: true)
require(fill.frame(at: 11).value == 0 && !fill.frame(at: 11).animating, "legal zero")
fill.receive(nil, at: 12, animate: true);fill.receive(99.9, at: 13, animate: false)
require(fill.frame(at: 13).value == 99.9 && !fill.frame(at: 13).animating, "hidden/reduced motion must be immediate")
require(RecoveryFill.text(99.9, animating: false) == "99%", "non-full rounded to 100")
fill.receive(nil, at: 14, animate: true);fill.receive(50, at: 15, animate: true);fill.finish()
require(fill.frame(at: 15).value == 50 && !fill.frame(at: 15).animating, "hide does not stop")
print("PASS recovery curve, retarget, duplicate success, 3 disconnect/recovery cycles, zero, hidden/reduced motion")
var status: SMAppService.Status = .notRegistered;var registrations = 0;var removals = 0;var fail = false
let login = LoginItemController(status: {status}, register: {if fail {throw NSError(domain:"test",code:1)};registrations += 1;status = .requiresApproval}, unregister:{removals += 1;status = .notRegistered})
require(registrations == 0 && login.status == .notRegistered, "default must not register")
try login.toggle();require(login.status == .requiresApproval && registrations == 1,"pending approval not reflected")
try login.toggle();require(removals == 1 && login.status == .notRegistered,"pending cancellation")
status = .enabled;try login.toggle();require(removals == 2,"enabled unregister")
fail = true;do { try login.toggle();preconditionFailure("expected failure") } catch {}
require(login.status == .notRegistered && registrations == 1,"registration error fabricated success")
print("PASS login default-off, system status, approval pending, cancellation, enabled and error paths; fake service only")
require(OverlayLabels.rate(nil) == "--" && OverlayLabels.rate(0) == "0B", "network unknown/zero")
let counters = ["en0": NetworkBytes(received: 10, sent: 20)]
require(NetworkRateCalculator.observedRates(previous: [:], current: counters, elapsed: 2, maximumGap: 6) == nil,"new baseline is unknown")
require(NetworkRateCalculator.observedRates(previous: counters, current: counters, elapsed: 2, maximumGap: 6)?.0 == 0,"measured idle is zero")
require(NetworkRateCalculator.observedRates(previous: counters, current: counters, elapsed: 10, maximumGap: 6) == nil,"gap should be unknown")
let model = OverlayModel();require(model.presentedPercentageText == "--%" && model.downloadBytesPerSecond == nil,"initial unknown")
model.updateRates(download: 0, upload: 123); model.snapshot = .unavailable("offline")
require(model.uploadBytesPerSecond == 123 && model.downloadBytesPerSecond == 0,"account failure cleared independent network")
model.setPresentationActive(true);model.snapshot = UsageSnapshot(remaining: 97, detail: "0 points", resetText: "5d")
if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
 require(model.isAnimatingRecovery && model.presentedRemaining == 0,"model animation did not start")
 RunLoop.current.run(until: Date().addingTimeInterval(0.9))
 require(!model.isAnimatingRecovery && model.presentedRemaining == 97,"transient timer leaked")
 model.snapshot = .unavailable("timeout");model.snapshot = UsageSnapshot(remaining: 50,detail:"",resetText:nil)
 require(model.isAnimatingRecovery,"recovery did not start")
 model.setPresentationActive(false);require(!model.isAnimatingRecovery && model.presentedRemaining == 50,"hidden timer leaked")
}
print("PASS unknown fields, measured zero, independent values and transient timer lifecycle")
