import AppKit
import Foundation

func require(_ value: Bool, _ message: String) { precondition(value, message) }
let trusted = URL(string: "https://github.com/ALEXESLAT/usage-topbar/releases/download/v0.5.0/UsageTopbar-0.5.0-macOS-arm64.zip")!
require(UpdatePolicy.permits(version: "22", installed: "21", download: trusted), "new integer build")
for version in ["20", "21", "021", "21.0", "-1", "18446744073709551616", "garbage"] {
    require(!UpdatePolicy.permits(version: version, installed: "21", download: trusted), "reject downgrade/replay/malformed build")
}
for url in [trusted.absoluteString.replacingOccurrences(of: "https:", with: "http:"),
            trusted.absoluteString.replacingOccurrences(of: "ALEXESLAT", with: "attacker"),
            trusted.absoluteString.replacingOccurrences(of: "github.com", with: "github.com.evil.test"),
            trusted.absoluteString + "?token=anything", trusted.absoluteString + "#fragment",
            trusted.absoluteString.replacingOccurrences(of: "github.com", with: "user@github.com"),
            trusted.absoluteString.replacingOccurrences(of: "arm64.zip", with: "arm64.pkg")] {
    require(!UpdatePolicy.permits(version: "22", installed: "21", download: URL(string: url)), "reject other source/type")
}
require(!UpdatePolicy.permits(version: "22", installed: "21", download: nil), "missing enclosure")
let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])), format: nil) as! [String: Any]
require(UpdatePolicy.configurationProblem(info)?.contains("公钥") == true, "keyless build must fail closed")
var bad = info; bad["CFBundleIdentifier"] = "wrong.app"
require(UpdatePolicy.configurationProblem(bad)?.contains("标识") == true, "wrong identity")
bad = info; bad["SUFeedURL"] = "http://example.test/feed.xml"
require(UpdatePolicy.configurationProblem(bad)?.contains("更新源") == true, "wrong feed")
for value in ["", "not base64", String(repeating: "A", count: 44)] {
    bad = info; bad["SUPublicEDKey"] = value
    require(UpdatePolicy.configurationProblem(bad) != nil, "bad key fails before network")
}
for name in ["SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"] {
    bad = info; bad[name] = false
    require(UpdatePolicy.configurationProblem(bad)?.contains("签名验证") == true, "authentication flag must fail closed")
}
for name in ["SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SUAllowsAutomaticUpdates", "SUEnableSystemProfiling", "SUEnableJavaScript"] {
    bad = info; bad[name] = true
    require(UpdatePolicy.configurationProblem(bad)?.contains("手动更新") == true, "manual/privacy flag")
}
bad = info; bad["SUSignedFeedFailureExpirationInterval"] = 0.5
require(UpdatePolicy.configurationProblem(bad)?.contains("失败时") == true, "no delayed authentication fallback")
let publicKeyPath = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent().appendingPathComponent("update-public-key.txt")
if let key = try? String(contentsOf: publicKeyPath, encoding: .utf8) {
    var configured = info; configured["SUPublicEDKey"] = key.trimmingCharacters(in: .whitespacesAndNewlines)
    require(UpdatePolicy.configurationProblem(configured) == nil, "approved public key enables valid configuration")
}
print("PASS integer upgrade/downgrade/replay, source allowlist, identity/feed mismatch, missing/malformed public key; no test key generated")

@MainActor
final class FakeEngine: ManualUpdateEngine {
    var canCheck = true
    var starts = 0, checks = 0
    var startError: Error?
    func start() throws { starts += 1; if let startError { throw startError } }
    func check() { checks += 1; canCheck = false }
}
MainActor.assumeIsolated {
    let engine = FakeEngine()
    var creates = 0, errors: [String] = []
    var blocked: String? = "missing signing configuration"
    let controller = AppUpdateController(problem: { blocked }, makeEngine: { creates += 1; return engine }, showError: { errors.append($0) })
    require(creates == 0 && engine.checks == 0, "no startup/background activity")
    controller.checkForUpdates()
    require(creates == 0 && errors.count == 1, "gate before engine/network")
    blocked = nil // Injected policy seam, NOT a key or a usable updater configuration.
    engine.startError = NSError(domain: "synthetic setup failure", code: 1)
    controller.checkForUpdates()
    require(engine.starts == 1 && engine.checks == 0 && errors.count == 2, "startup failure keeps check stopped")
    engine.startError = nil
    controller.checkForUpdates()
    require(creates == 2 && engine.starts == 2 && engine.checks == 1, "explicit retry starts a fresh engine")
    controller.checkForUpdates()
    require(engine.checks == 1, "busy prevents duplicate checks")
    engine.canCheck = true // An ended/cancelled session exposes canCheck again.
    controller.checkForUpdates()
    require(engine.checks == 2 && engine.starts == 2, "explicit check after session completion reuses updater")
    print("PASS lazy manual dispatch, gate/start failure, retry and busy guard; simulated engine completion only")
    #if canImport(Sparkle)
    let real = SparkleUpdateEngine()
    do { try real.start(); preconditionFailure("unconfigured test host unexpectedly started") }
    catch { print("PASS actual Sparkle rejects unconfigured host before checking") }
    #endif
}
