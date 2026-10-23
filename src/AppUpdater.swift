import AppKit
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

enum UpdateChannel: String, CaseIterable {
    case stable, beta
    var title: String { self == .stable ? updateText("正式版", "Stable") : updateText("测试版", "Beta") }
}
func updateText(_ zh: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

// Strict SemVer precedence; integer builds remain a separate anti-downgrade gate.
struct UpdateVersion: Comparable {
    let core: [UInt64]
    let prerelease: [String]
    init?(_ value: String) {
        let pattern = "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
        guard value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let main = String(value.split(separator: "+", maxSplits: 1)[0])
        let parts = main.split(separator: "-", maxSplits: 1)
        core = parts[0].split(separator: ".").compactMap { UInt64($0) }
        guard core.count == 3 else { return nil }
        prerelease = parts.count == 2 ? parts[1].split(separator: ".").map(String.init) : []
        guard !prerelease.contains(where: { $0.allSatisfy(\.isNumber) && $0.count > 1 && $0.first == "0" }) else { return nil }
    }
    static func < (a: Self, b: Self) -> Bool {
        if a.core != b.core { return a.core.lexicographicallyPrecedes(b.core) }
        if a.prerelease.isEmpty || b.prerelease.isEmpty { return !a.prerelease.isEmpty && b.prerelease.isEmpty }
        for (x,y) in zip(a.prerelease,b.prerelease) where x != y {
            let xn = x.allSatisfy(\.isNumber), yn = y.allSatisfy(\.isNumber)
            if xn != yn { return xn }
            if xn && x.count != y.count { return x.count < y.count }
            return x < y
        }
        return a.prerelease.count < b.prerelease.count
    }
}

struct UpdateCandidate {
    let build: String
    let version: String
    let channel: String?
    let releaseStatus: String?
    let url: URL?
    let notes: String?
    func eligible(for selected: UpdateChannel, installedBuild: String, installedVersion: String) -> Bool {
        guard let next = UpdateVersion(version), let current = UpdateVersion(installedVersion), next >= current,
              UpdatePolicy.permits(version: build, installed: installedBuild, download: url),
              UpdatePolicy.presentationProblem(version: build, displayVersion: version, download: url, notes: notes) == nil else { return false }
        // Only explicitly published release metadata is eligible. Missing, draft
        // or unknown status fails closed on both channels.
        let isBeta = channel == "beta"
        guard channel == nil || isBeta else { return false }
        if isBeta {
            return selected == .beta && releaseStatus == "prerelease" && !next.prerelease.isEmpty
        }
        return next.prerelease.isEmpty && releaseStatus == "published"
    }
    // A rejected newer item in the selected channel must not become “up to date”.
    func hasInvalidMetadata(for selected: UpdateChannel, installedBuild: String) -> Bool {
        guard channel == nil || (selected == .beta && channel == "beta"),
              releaseStatus != "draft", let buildNumber = UInt64(build),
              let installed = UInt64(installedBuild), buildNumber > installed else { return false }
        guard let parsed = UpdateVersion(version) else { return true }
        return UpdatePolicy.presentationProblem(version: build, displayVersion: version, download: url, notes: notes) != nil
            || (channel == "beta" ? releaseStatus != "prerelease" || parsed.prerelease.isEmpty
                : releaseStatus != "published" || !parsed.prerelease.isEmpty)
    }
    static func best(_ items: [Self], channel: UpdateChannel, installedBuild: String, installedVersion: String) -> Int? {
        items.indices.filter { items[$0].eligible(for: channel, installedBuild: installedBuild, installedVersion: installedVersion) }.max {
            let a = UpdateVersion(items[$0].version)!, b = UpdateVersion(items[$1].version)!
            return a == b ? UInt64(items[$0].build)! < UInt64(items[$1].build)! : a < b
        }
    }
}

// No account information is available to this updater. Sparkle owns download,
// authentication, installation and relaunch; we never execute a downloaded script.
enum UpdatePolicy {
    static let feed = "https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/main/updates/appcast.xml"
    static let bundleID = "local.alex.usage-topbar"

    static func configurationProblem(_ info: [String: Any]) -> String? {
        #if USAGE_TOPBAR_TESTING
        return "测试版不连接正式更新通道。"
        #else
        guard info["CFBundleIdentifier"] as? String == bundleID else { return "应用标识不匹配。" }
        guard info["UsageTopbarStrictUpdateValidation"] as? Bool == true else { return "安装前身份和版本验证未启用。" }
        guard info["SUFeedURL"] as? String == feed else { return "更新源配置不正确。" }
        for name in ["SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"] {
            guard info[name] as? Bool == true else { return "更新签名验证未启用。" }
        }
        for name in ["SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SUAllowsAutomaticUpdates", "SUEnableSystemProfiling", "SUEnableJavaScript"] {
            guard info[name] as? Bool == false else { return "此版本只支持手动更新，且不上传系统画像。" }
        }
        guard (info["SUSignedFeedFailureExpirationInterval"] as? NSNumber)?.doubleValue == 0 else {
            return "更新验证必须在失败时保持关闭。"
        }
        guard info["SUShowReleaseNotes"] as? Bool == true else { return "更新说明显示未启用。" }
        guard let key = info["SUPublicEDKey"] as? String,
              let bytes = Data(base64Encoded: key), bytes.count == 32,
              bytes.contains(where: { $0 != 0 }) else {
            return "此开发版尚未配置更新验证公钥。当前应用保持不变；请使用正式发布页的安装包。"
        }
        return nil
        #endif
    }

    // All release facts belong to the authenticated appcast item, never to UI literals.
    // Reject inconsistent/missing presentation data before Sparkle offers this update.
    static func presentationProblem(version: String, displayVersion: String, download: URL?, notes: String?) -> String? {
        guard let download, permits(version: version, installed: "0", download: download),
              download.pathComponents.dropLast().last == "v" + displayVersion else {
            return "未获取到一致的更新版本信息。当前应用保持不变，请稍后重试。"
        }
        guard let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "未获取到此版本的更新说明。当前应用保持不变，请稍后重试。"
        }
        return nil
    }

    static func permits(version: String, installed: String, download: URL?) -> Bool {
        // This project uses positive integer CFBundleVersion values, never marketing versions.
        guard let next = UInt64(version), let current = UInt64(installed), next > current,
              String(next) == version, let url = download,
              url.scheme == "https", url.host == "github.com", url.port == nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 6, parts[0...3] == ["ALEXESLAT", "usage-topbar", "releases", "download"],
              parts[4].hasPrefix("v"), UpdateVersion(String(parts[4].dropFirst())) != nil else { return false }
        let releaseVersion = String(parts[4].dropFirst())
        return parts[5] == "UsageTopbar-\(releaseVersion)-macOS-arm64.zip"
    }
}

@MainActor
protocol ManualUpdateEngine: AnyObject {
    var canCheck: Bool { get }
    func start() throws
    func check()
    var canChangeChannel: Bool { get }
    func setChannel(_ channel: UpdateChannel)
}
extension ManualUpdateEngine {
    var canChangeChannel: Bool { true }
    func setChannel(_ channel: UpdateChannel) {}
}

@MainActor
final class AppUpdateController {
    private var engine: ManualUpdateEngine?
    private let problem: () -> String?
    private let makeEngine: () -> ManualUpdateEngine
    private let showError: (String) -> Void
    private let readChannel: () -> String?
    private let writeChannel: (String) -> Void
    static let channelKey = "updates.channel"
    var channel: UpdateChannel { UpdateChannel(rawValue: readChannel() ?? "") ?? .stable }

    init(problem: @escaping () -> String?, makeEngine: @escaping () -> ManualUpdateEngine,
         showError: @escaping (String) -> Void, defaults: UserDefaults = .standard,
         readChannel: (() -> String?)? = nil, writeChannel: ((String) -> Void)? = nil) {
        self.problem = problem; self.makeEngine = makeEngine; self.showError = showError
        self.readChannel = readChannel ?? { defaults.string(forKey: Self.channelKey) }
        self.writeChannel = writeChannel ?? { defaults.set($0, forKey: Self.channelKey) }
    }

    // Lazy: opening the app (including --mock) does not create an updater, network
    // request, permission prompt, scheduled check, or install-on-quit session.
    func checkForUpdates() {
        if let reason = problem() { showError(reason); return }
        if engine == nil {
            let candidate = makeEngine()
            candidate.setChannel(channel)
            do { try candidate.start(); engine = candidate }
            catch { showError("未能启动更新检查：" + error.localizedDescription); return }
        }
        guard let engine, engine.canCheck else { return }
        engine.check()
    }

    @discardableResult func selectChannel(_ value: UpdateChannel) -> Bool {
        guard value != channel else { return true }
        guard engine?.canChangeChannel != false else {
            showError(updateText("安装已开始，完成后再切换更新通道。", "Installation has started. Change channels after it finishes.")); return false
        }
        writeChannel(value.rawValue)
        if let engine { engine.setChannel(value) }
        else { checkForUpdates() }
        return true
    }

    static func production(bundle: Bundle = .main) -> AppUpdateController {
        AppUpdateController(problem: {
            #if canImport(Sparkle)
            return UpdatePolicy.configurationProblem(bundle.infoDictionary ?? [:])
            #else
            return "此构建未包含更新组件。"
            #endif
        }, makeEngine: {
            #if canImport(Sparkle)
            return SparkleUpdateEngine()
            #else
            preconditionFailure("Configuration gate prevents missing framework use")
            #endif
        }, showError: { message in
            let alert = NSAlert()
            alert.messageText = "无法检查更新"
            alert.informativeText = message
            alert.addButton(withTitle: "好")
            alert.runModal()
        })
    }
}

#if canImport(Sparkle)
// Retain Sparkle's standard UI and its actual cancellation/installation callbacks.
// A channel switch invalidates every old UI reply before requesting cancellation.
@MainActor
final class ChannelUserDriver: SPUStandardUserDriver {
    var acceptsCandidate: (SUAppcastItem) -> Bool = { _ in false }
    private var cancel: (() -> Void)?
    private var epoch = 0
    var unavailableReason: String?
    private(set) var obsolete = false
    private(set) var installing = false
    func begin() { epoch += 1; unavailableReason = nil; obsolete = false; cancel = nil; installing = false }
    func sessionReply<T>(_ action: @escaping (T) -> Void) -> (T) -> Void {
        let token = epoch
        return { [weak self] value in
            guard let self, !self.obsolete, self.epoch == token else { return }
            self.cancel = nil; action(value)
        }
    }
    func invalidate() {
        epoch += 1; obsolete = true
        let action = cancel; cancel = nil
        super.dismissUpdateInstallation()
        action?()
    }
    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        guard !obsolete else { cancellation(); return }
        cancel = cancellation
        super.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }
    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !obsolete, acceptsCandidate(appcastItem) else { reply(.skip); return }
        cancel = { reply(.skip) }
        super.showUpdateFound(with: appcastItem, state: state, reply: sessionReply { [weak self] choice in
            if state.stage == .installing { self?.installing = choice != .skip }
            reply(choice)
        })
    }
    override func showDownloadInitiated(cancellation: @escaping () -> Void) {
        guard !obsolete else { cancellation(); return }
        cancel = cancellation
        super.showDownloadInitiated(cancellation: cancellation)
    }
    override func showDownloadDidStartExtractingUpdate() {
        cancel = nil
        if !obsolete { super.showDownloadDidStartExtractingUpdate() }
    }
    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !obsolete else { reply(.skip); return }
        cancel = { reply(.skip) }
        super.showReady(toInstallAndRelaunch: sessionReply { [weak self] choice in
            self?.installing = choice != .skip; reply(choice)
        })
    }
    override func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        if !obsolete { super.showDownloadDidReceiveExpectedContentLength(expectedContentLength) }
    }
    override func showDownloadDidReceiveData(ofLength length: UInt64) {
        if !obsolete { super.showDownloadDidReceiveData(ofLength: length) }
    }
    override func showExtractionReceivedProgress(_ progress: Double) {
        if !obsolete { super.showExtractionReceivedProgress(progress) }
    }
    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        guard !obsolete else { acknowledgement(); return }
        let token = epoch; cancel = acknowledgement
        let done = { [weak self] in
            guard let self, !self.obsolete, self.epoch == token else { return }
            self.cancel = nil; acknowledgement()
        }
        if let reason = unavailableReason {
            super.showUpdaterError(NSError(domain: "UsageTopbar.UpdateMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]), acknowledgement: done)
        } else { super.showUpdateNotFoundWithError(error, acknowledgement: done) }
    }
    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        installing = false
        guard !obsolete else { acknowledgement(); return }
        let token = epoch; cancel = acknowledgement
        super.showUpdaterError(error, acknowledgement: { [weak self] in
            guard let self, !self.obsolete, self.epoch == token else { return }
            self.cancel = nil; acknowledgement()
        })
    }

}

@MainActor
final class SparkleUpdateEngine: NSObject, ManualUpdateEngine, SPUUpdaterDelegate {
    private var updater: SPUUpdater!
    private let driver = ChannelUserDriver(hostBundle: .main, delegate: nil)
    private var channel: UpdateChannel = .stable
    private var activeChannel: UpdateChannel = .stable
    private var generation = 0
    private var activeGeneration = 0
    private var started = false
    private var pendingCheck = false
    override init() {
        super.init()
        driver.acceptsCandidate = { [weak self] item in
            guard let self, self.activeGeneration == self.generation else { return false }
            return self.candidate(item).eligible(for: self.channel,
                installedBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                installedVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        }
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
    }
    var canCheck: Bool { updater.canCheckForUpdates }
    var canChangeChannel: Bool { !driver.installing }
    func start() throws {
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false
        updater.sendsSystemProfile = false
        try updater.start(); started = true
    }
    func check() {
        guard canCheck else { return }
        pendingCheck = false; activeChannel = channel; activeGeneration = generation
        driver.begin(); updater.checkForUpdates()
    }
    func setChannel(_ value: UpdateChannel) {
        guard value != channel else { return }
        channel = value; generation += 1
        guard started else { return }
        pendingCheck = true
        driver.invalidate()
        if !updater.sessionInProgress { check() }
    }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { activeChannel == .beta ? ["beta"] : [] }
    private func candidate(_ item: SUAppcastItem) -> UpdateCandidate {
        UpdateCandidate(build: item.versionString, version: item.displayVersionString, channel: item.channel,
            releaseStatus: item.propertiesDictionary["sparkle:releaseStatus"] as? String, url: item.fileURL, notes: item.itemDescription)
    }
    func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        guard activeGeneration == generation else { return SUAppcastItem.empty() }
        let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let candidates = appcast.items.map(candidate)
        guard let index = UpdateCandidate.best(candidates, channel: activeChannel,
                installedBuild: installedBuild, installedVersion: installedVersion) else {
            if candidates.contains(where: { item in
                item.hasInvalidMetadata(for: activeChannel, installedBuild: installedBuild)
            }) {
                driver.unavailableReason = updateText("未获取到完整的已签名发布信息，无法确认更新。请稍后重试。", "Complete signed release metadata was not obtained. Unable to confirm updates; please retry later.")
            }
            return SUAppcastItem.empty()
        }
        driver.unavailableReason = nil
        return appcast.items[index]
    }
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard updateCheck == .updates else { throw rejected("仅允许用户发起更新检查。") }
    }
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard activeGeneration == generation, updateCheck == .updates,
              candidate(item).eligible(for: channel,
                installedBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                installedVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") else {
            throw rejected(updateText("更新通道、版本或发布元数据不符合要求，当前版本保持不变。", "Update channel, version or release metadata is invalid. The current version is unchanged."))
        }
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        guard pendingCheck else { return }
        let epoch = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == epoch, self.pendingCheck else { return }
            self.check()
        }
    }
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool { false }
    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }
    func feedParameters(for updater: SPUUpdater, sendingSystemProfile: Bool) -> [[String: String]] { [] }
    func updater(_ updater: SPUUpdater, shouldDownloadReleaseNotesForUpdate item: SUAppcastItem) -> Bool { false }
    private func rejected(_ message: String) -> NSError {
        NSError(domain: "UsageTopbar.UpdatePolicy", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
#endif
