import AppKit
import Foundation

func require(_ value: Bool, _ message: String) { precondition(value, message) }
if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--verify-channel" {
    let domain = CommandLine.arguments[2]
    require(domain.hasPrefix("local.alex.usage.channel-test."),"only isolated test preferences")
    require(UserDefaults(suiteName:domain)?.string(forKey:"updates.channel") == "beta","channel persisted across process restart")
    print("PASS persisted channel in a new process"); exit(0)
}

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
for name in ["UsageTopbar-Testing-0.6.0-macOS-arm64.zip", "UsageTopbar-0.5.0-dev-macOS-arm64.zip", "UsageTopbar-0.6.0-macOS-arm64.zip"] {
    let url = trusted.deletingLastPathComponent().appendingPathComponent(name)
    require(!UpdatePolicy.permits(version: "22", installed: "21", download: url), "test/dev/mismatched assets rejected")
}
require(!UpdatePolicy.permits(version: "22", installed: "21", download: nil), "missing enclosure")
let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])), format: nil) as! [String: Any]
require(UpdatePolicy.configurationProblem(info)?.contains("公钥") == true, "keyless build must fail closed")
var missingGuard = info; missingGuard["UsageTopbarStrictUpdateValidation"] = false
require(UpdatePolicy.configurationProblem(missingGuard)?.contains("安装前") == true, "strict package guard cannot be disabled")
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
    var canChangeChannel = true
    var selected: [UpdateChannel] = []
    func setChannel(_ value: UpdateChannel) { selected.append(value) }
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

for (version, build) in [("1.2.3", "53"), ("7.8.9", "90")] {
    let url=URL(string:"https://github.com/ALEXESLAT/usage-topbar/releases/download/v\(version)/UsageTopbar-\(version)-macOS-arm64.zip")!
    require(UpdatePolicy.presentationProblem(version:build,displayVersion:version,download:url,notes:"Version-specific signed notes") == nil,"matching signed item")
    require(UpdatePolicy.presentationProblem(version:build,displayVersion:"0.1.0",download:url,notes:"stale text") != nil,"stale display version rejected")
    for notes:String? in [nil,"","  \n"] {
        require(UpdatePolicy.presentationProblem(version:build,displayVersion:version,download:url,notes:notes)?.contains("未获取") == true,"missing notes never become stale release facts")
    }
    require(UpdatePolicy.presentationProblem(version:build,displayVersion:version,download:url,notes:"Fresh retry notes") == nil,"retry reads current item without presentation cache")
}
print("PASS dynamic item version binding, missing notes, stale version rejection and stateless retry")

func fixture(_ version: String, _ build: String, channel: String? = nil, status: String? = "published") -> UpdateCandidate {
    UpdateCandidate(build: build, version: version, channel: channel, releaseStatus: status,
        url: URL(string: "https://github.com/ALEXESLAT/usage-topbar/releases/download/v\(version)/UsageTopbar-\(version)-macOS-arm64.zip"), notes: "Signed fixture notes")
}
let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.10", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.10.0"]
for (a,b) in zip(ordered,ordered.dropFirst()) { require(UpdateVersion(a)! < UpdateVersion(b)!, "semantic precedence \(a) < \(b)") }
require(UpdateVersion("1.0.0+local") == UpdateVersion("1.0.0+other"), "build metadata does not affect precedence")
for bad in ["01.0.0", "1.0", "1.0.0-beta.01", "1.0.0-", "1.0.0+", "1.0.0/beta", "1.0.0.."] { require(UpdateVersion(bad) == nil,"invalid SemVer") }
let releases = [fixture("1.1.0-beta.10","103",channel:"beta",status:"prerelease"), fixture("1.1.0-beta.2","102",channel:"beta",status:"prerelease"), fixture("1.0.1","101"), fixture("1.1.0","104")]
for channel in UpdateChannel.allCases {
    require(UpdateCandidate.best(releases,channel:channel,installedBuild:"100",installedVersion:"1.0.0") == 3,"newer stable wins on either channel")
}
require(UpdateCandidate.best(Array(releases.prefix(3)),channel:.beta,installedBuild:"100",installedVersion:"1.0.0") == 0,"beta.10 beats beta.2")
require(UpdateCandidate.best(Array(releases.prefix(3)),channel:.stable,installedBuild:"100",installedVersion:"1.0.0") == 2,"stable excludes prereleases")
require(UpdateCandidate.best([releases[2]],channel:.beta,installedBuild:"100",installedVersion:"1.0.0") == 0,"no beta still permits stable")
require(UpdateCandidate.best([],channel:.beta,installedBuild:"100",installedVersion:"1.0.0") == nil,"empty feed")
for item in [fixture("1.1.0","105",status:"draft"),fixture("1.1.0","105",status:nil),fixture("1.1.0","105",status:"prerelease"),fixture("1.1.0-beta.1","105"),fixture("1.1.0-beta.1","105",channel:"beta",status:nil),fixture("1.1.0","105",channel:"unknown"),fixture("1.1.0","99"),fixture("0.9.0","105")] {
    for channel in UpdateChannel.allCases { require(!item.eligible(for:channel,installedBuild:"100",installedVersion:"1.0.0"),"draft, missing/inconsistent metadata, unknown channel and either downgrade excluded") }
}
require(!releases[2].eligible(for:.stable,installedBuild:"103",installedVersion:"1.1.0-beta.10"),"returning stable never downgrades")
MainActor.assumeIsolated {
    let domain = "local.alex.usage.channel-test." + UUID().uuidString
    let defaults = UserDefaults(suiteName:domain)!
    defer { defaults.removePersistentDomain(forName:domain) }
    let engine = FakeEngine(); var errors:[String] = []
    let controller = AppUpdateController(problem:{nil},makeEngine:{engine},showError:{errors.append($0)},defaults:defaults)
    require(controller.channel == .stable,"default stable")
    require(controller.selectChannel(.beta) && controller.channel == .beta && engine.checks == 1,"selecting channel checks immediately")
    require(defaults.synchronize(),"flush isolated preference for cross-process test")
    let reload = Process(); reload.executableURL = URL(fileURLWithPath:CommandLine.arguments[0])
    reload.arguments = ["--verify-channel",domain]
    try! reload.run(); reload.waitUntilExit()
    require(reload.terminationStatus == 0,"restart persistence")
    let reopened = AppUpdateController(problem:{nil},makeEngine:{engine},showError:{_ in},defaults:UserDefaults(suiteName:domain)!)
    require(reopened.channel == .beta,"selection survives controller and defaults recreation")
    require(controller.selectChannel(.stable) && engine.selected.last == .stable,"busy switch reaches cancellation engine")
    engine.canChangeChannel = false
    require(!controller.selectChannel(.beta) && controller.channel == .stable && errors.count == 1,"committed install cannot change channel or persist a false selection")
    defaults.set("invalid",forKey:AppUpdateController.channelKey)
    require(controller.channel == .stable,"unknown preference falls back stable")
    #if canImport(Sparkle)
    let item = SUAppcastItem(dictionary: ["sparkle:version":"103","sparkle:shortVersionString":"1.1.0-beta.10","sparkle:channel":"beta","sparkle:releaseStatus":"prerelease","enclosure":["url":releases[0].url!.absoluteString]])!
    require(item.propertiesDictionary["sparkle:releaseStatus"] as? String == "prerelease" && item.channel == "beta","actual Sparkle preserves signed custom metadata")
    let driver = ChannelUserDriver(hostBundle:.main,delegate:nil)
    driver.begin()
    var replies = 0
    let oldReply = driver.sessionReply { (_: Bool) in replies += 1 }
    driver.invalidate(); driver.begin(); oldReply(true)
    require(replies == 0,"previous generation UI reply cannot apply after new channel begins")
    let newReply = driver.sessionReply { (_: Bool) in replies += 1 }; newReply(true)
    require(replies == 1,"current generation reply is delivered")
    driver.invalidate()
    var cancelled = 0, acknowledged = 0
    driver.showUserInitiatedUpdateCheck { cancelled += 1 }
    driver.showDownloadInitiated { cancelled += 1 }
    driver.showReady(toInstallAndRelaunch: { choice in require(choice == .skip,"obsolete staged update cancelled"); cancelled += 1 })
    driver.showUpdaterError(NSError(domain:"fixture",code:1),acknowledgement:{acknowledged += 1})
    driver.showUpdateNotFoundWithError(NSError(domain:"fixture",code:2),acknowledgement:{acknowledged += 1})
    require(cancelled == 3 && acknowledged == 2,"late old callbacks cancel/acknowledge without presenting stale UI")
    driver.begin(); require(!driver.obsolete,"next generation can show fresh results")
    // Recovered downloads must pass the same gate before Sparkle can present them.
    driver.acceptsCandidate = { _ in false }
    var rejectedResume = false
    let stateArchive = NSKeyedArchiver(requiringSecureCoding: true)
    stateArchive.encode(SPUUserUpdateStage.downloaded.rawValue, forKey: "SPUUserUpdateStateStage")
    stateArchive.encode(true, forKey: "SPUUserUpdateStateUserInitiated")
    stateArchive.finishEncoding()
    let stateDecoder = try! NSKeyedUnarchiver(forReadingFrom: stateArchive.encodedData)
    let resumedState = SPUUserUpdateState(coder: stateDecoder)!
    require(resumedState.stage == .downloaded, "fixture represents downloaded stage")
    driver.showUpdateFound(with: item, state: resumedState, reply: { choice in rejectedResume = choice == .skip })
    require(rejectedResume, "resumed stale candidate skipped before UI")
    #endif
}
print("PASS channel persistence/defaults, SemVer suffixes, stable/beta selection, no beta, empty feed, drafts, downgrade, install lock and stale callback suppression")

let mismatched = UpdateCandidate(build: "106", version: "1.2.0", channel: nil, releaseStatus: "published", url: releases[2].url, notes: "Signed but mismatched")
require(mismatched.hasInvalidMetadata(for: .stable, installedBuild: "100"), "mismatched URL yields metadata failure, not up to date")
require(fixture("1.2.0-beta.1", "106").hasInvalidMetadata(for: .stable, installedBuild: "100"), "invalid suffix/status reported")
require(!releases[0].hasInvalidMetadata(for: .stable, installedBuild: "100"), "other channel is ignored")
require(!fixture("1.2.0", "106", status: "draft").hasInvalidMetadata(for: .stable, installedBuild: "100"), "draft is ignored")
print("PASS selected-channel inconsistent metadata reporting")
