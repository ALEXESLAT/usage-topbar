import AppKit
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

// No account information is available to this updater. Sparkle owns download,
// authentication, installation and relaunch; we never execute a downloaded script.
enum UpdatePolicy {
    static let feed = "https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/updater-https-validation/updates/appcast.xml"
    static let bundleID = "local.alex.usage-topbar.https-test"

    static func configurationProblem(_ info: [String: Any]) -> String? {
        guard info["CFBundleIdentifier"] as? String == bundleID else { return "应用标识不匹配。" }
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
        guard let key = info["SUPublicEDKey"] as? String,
              let bytes = Data(base64Encoded: key), bytes.count == 32,
              bytes.contains(where: { $0 != 0 }) else {
            return "此开发版尚未配置更新验证公钥。当前应用保持不变；请使用正式发布页的安装包。"
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
        return parts.count == 6 && parts[0...3] == ["ALEXESLAT", "usage-topbar", "releases", "download"]
            && parts[4].hasPrefix("v") && parts[5].hasPrefix("UsageTopbar-")
            && parts[5].hasSuffix("-macOS-arm64.zip")
    }
}

@MainActor
protocol ManualUpdateEngine: AnyObject {
    var canCheck: Bool { get }
    func start() throws
    func check()
}

@MainActor
final class AppUpdateController {
    private var engine: ManualUpdateEngine?
    private let problem: () -> String?
    private let makeEngine: () -> ManualUpdateEngine
    private let showError: (String) -> Void

    init(problem: @escaping () -> String?, makeEngine: @escaping () -> ManualUpdateEngine,
         showError: @escaping (String) -> Void) {
        self.problem = problem; self.makeEngine = makeEngine; self.showError = showError
    }

    // Lazy: opening the app (including --mock) does not create an updater, network
    // request, permission prompt, scheduled check, or install-on-quit session.
    func checkForUpdates() {
        if let reason = problem() { showError(reason); return }
        if engine == nil {
            let candidate = makeEngine()
            do { try candidate.start(); engine = candidate }
            catch { showError("未能启动更新检查：" + error.localizedDescription); return }
        }
        guard let engine, engine.canCheck else { return }
        engine.check()
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
@MainActor
final class SparkleUpdateEngine: NSObject, ManualUpdateEngine, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController!
    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    func start() throws {
        // Explicitly override any stale preference from a previous installation.
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        controller.updater.sendsSystemProfile = false
        try controller.updater.start()
    }
    func check() { controller.checkForUpdates(nil) }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard updateCheck == .updates else { throw rejected("仅允许用户发起更新检查。") }
    }
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard updateCheck == .updates,
              UpdatePolicy.permits(version: item.versionString,
                                   installed: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                                   download: item.fileURL) else {
            throw rejected("更新版本或下载来源不符合本应用要求。当前版本保持不变。")
        }
    }
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool { false }
    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }
    func feedParameters(for updater: SPUUpdater, sendingSystemProfile: Bool) -> [[String: String]] { [] }
    func updater(_ updater: SPUUpdater, shouldDownloadReleaseNotesForUpdate item: SUAppcastItem) -> Bool { false }
    private func rejected(_ message: String) -> NSError {
        NSError(domain: "UsageTopbar.UpdatePolicy", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    // Sparkle standard UI owns no-update, network/download/signature errors and
    // cancel/skip/install consent. NSApplication termination runs the existing
    // app-server/timer cleanup before Sparkle's external installer relaunches us.
}
#endif
