import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOKit.ps
import Network
import ScreenCaptureKit
import SwiftUI

struct UsageSnapshot {
    let remaining: Double?
    let detail: String
    let resetText: String?

    var percentageText: String {
        guard let remaining, remaining.isFinite else { return "--%" }
        return "\(Int(max(0, min(100, remaining)).rounded()))%"
    }

    static func unavailable(_ reason: String) -> UsageSnapshot {
        UsageSnapshot(remaining: nil, detail: reason, resetText: nil)
    }

    static let mock = UsageSnapshot(
        remaining: 68,
        detail: "1 day  ·  120 points",
        resetText: "3h"
    )
}

enum GPTConnectionState: Equatable {
    case checking
    case connected
    case disconnected

    var color: Color {
        switch self {
        case .checking: return .yellow
        case .connected: return .green
        case .disconnected: return .red
        }
    }

    var label: String {
        switch self {
        case .checking: return "正在检查 Codex 服务连接"
        case .connected: return "Codex 服务已连接"
        case .disconnected: return "Codex 服务不可用"
        }
    }
}

final class OverlayModel: ObservableObject {
    @Published var snapshot: UsageSnapshot = .unavailable("Checking Codex…")
    @Published var isDarkBackground = true
    @Published var connectionState: GPTConnectionState = .checking
    @Published var downloadBytesPerSecond: Double = 0
    @Published var uploadBytesPerSecond: Double = 0
}

/// A 74-point rounded rectangle whose lower 22 points sit behind the Codex
/// window. Its left edge stays vertical through the Codex corner before the
/// 10-point bottom radius begins.
struct WindowEdgeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topRadius: CGFloat = min(18, rect.height * 0.36)
        let bottomRadius: CGFloat = min(10, rect.height)
        let topControl: CGFloat = topRadius * 0.52
        let bottomControl: CGFloat = bottomRadius * 0.5522848
        let connectionY = rect.maxY - bottomRadius
        var path = Path()
        path.move(to: CGPoint(x: 0, y: connectionY))
        path.addLine(to: CGPoint(x: 0, y: topRadius))
        path.addCurve(
            to: CGPoint(x: topRadius, y: 0),
            control1: CGPoint(x: 0, y: topRadius - topControl),
            control2: CGPoint(x: topRadius - topControl, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: 0))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: topRadius),
            control1: CGPoint(x: rect.maxX - topRadius + topControl, y: 0),
            control2: CGPoint(x: rect.maxX, y: topRadius - topControl)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: connectionY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: connectionY + bottomControl),
            control2: CGPoint(x: rect.maxX - bottomRadius + bottomControl, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: bottomRadius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: 0, y: connectionY),
            control1: CGPoint(x: bottomRadius - bottomControl, y: rect.maxY),
            control2: CGPoint(x: 0, y: connectionY + bottomControl)
        )
        path.closeSubpath()
        return path
    }
}

struct UsageEdgeTabView: View {
    @ObservedObject var model: OverlayModel

    private var remaining: Double {
        max(0, min(100, model.snapshot.remaining ?? 0))
    }

    private var primaryColor: Color {
        model.isDarkBackground ? .white : .black.opacity(0.84)
    }

    private var secondaryColor: Color {
        model.isDarkBackground ? .white.opacity(0.88) : .black.opacity(0.72)
    }

    private var glassTint: Color {
        .black.opacity(model.isDarkBackground ? 0.16 : 0.06)
    }

    private var fallbackTint: Color {
        model.isDarkBackground
            ? .black.opacity(0.20)
            : .white.opacity(0.18)
    }

    private var glassBorderColor: Color {
        primaryColor.opacity(0.20)
    }

    private var progressColor: Color {
        if model.snapshot.remaining == nil { return .gray }
        if remaining <= 20 { return .red }
        if remaining <= 50 { return .orange }
        return .green
    }

    private var accessibilityDetail: String {
        var text = model.snapshot.detail
        if let reset = model.snapshot.resetText, !reset.isEmpty {
            if !text.isEmpty { text += "  ·  " }
            text += "reset \(reset)"
        }
        return text
    }

    private func compactRate(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        if value < 1_024 { return "\(Int(value.rounded()))B" }
        if value < 1_048_576 { return "\(Int((value / 1_024).rounded()))K" }
        let megabytes = value / 1_048_576
        if megabytes < 10 {
            return String(format: "%.1fM", megabytes).replacingOccurrences(of: ".0M", with: "M")
        }
        return "\(Int(megabytes.rounded()))M"
    }

    private var throughputAccessibilityText: String {
        "整机下载每秒 \(compactRate(model.downloadBytesPerSecond))，整机上传每秒 \(compactRate(model.uploadBytesPerSecond))"
    }

    fileprivate var statusAccessory: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Text("CODEX")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                Circle()
                    .fill(model.connectionState.color)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(primaryColor.opacity(0.64), lineWidth: 0.8)
                    }
            }

            Text("↓\(compactRate(model.downloadBytesPerSecond))")
            Text("↑\(compactRate(model.uploadBytesPerSecond))")
        }
        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(primaryColor.opacity(0.92))
        .frame(width: 42, alignment: .trailing)
        .padding(.top, 9)
        .padding(.trailing, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(model.connectionState.label)。\(throughputAccessibilityText)"
        )
    }

    fileprivate var content: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.13))
                Circle()
                    .stroke(primaryColor.opacity(0.18), lineWidth: 0.7)
                Text("∞")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(primaryColor)
            }
            .frame(width: 28, height: 28)

            Text(model.snapshot.percentageText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryColor)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(model.snapshot.detail)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 7) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(primaryColor.opacity(0.16))
                        Capsule()
                            .fill(progressColor)
                            .frame(width: 112 * remaining / 100)
                    }
                    .frame(width: 112, height: 5)

                    if let reset = model.snapshot.resetText, !reset.isEmpty {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(reset)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }
            .foregroundStyle(secondaryColor)
            .minimumScaleFactor(0.92)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 44)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(width: 328, height: 52)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var glassContent: some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(glassTint), in: WindowEdgeTabShape())
        } else {
            content
                .background {
                    WindowEdgeTabShape()
                        .fill(fallbackTint)
                }
                .background {
                    WindowEdgeTabShape()
                        .fill(.ultraThinMaterial)
                }
        }
    }

    var body: some View {
        glassContent
            .overlay(alignment: .topTrailing) {
                statusAccessory
            }
            .overlay {
                WindowEdgeTabShape()
                    .stroke(
                        glassBorderColor,
                        lineWidth: 0.7
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Codex remaining usage \(model.snapshot.percentageText). \(accessibilityDetail). \(model.connectionState.label). \(throughputAccessibilityText)"
            )
    }
}

/// Deterministic documentation renderer. Liquid Glass requires a live desktop
/// compositor, so preview generation reuses the exact SwiftUI content and shape
/// with a representative dark backing instead.
struct UsageEdgeTabPreview: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        UsageEdgeTabView(model: model)
            .content
            .background {
                WindowEdgeTabShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .darkGray).opacity(0.92),
                                Color(nsColor: .black).opacity(0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                WindowEdgeTabShape()
                    .stroke(Color.white.opacity(0.62), lineWidth: 0.7)
            }
            .overlay(alignment: .topTrailing) {
                UsageEdgeTabView(model: model).statusAccessory
            }
    }
}

final class RateLimitClient {
    var onSnapshot: ((UsageSnapshot) -> Void)?
    var onStatus: ((String) -> Void)?
    var onConnectionState: ((GPTConnectionState) -> Void)?

    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errors: FileHandle?
    private var buffer = Data()
    private var requestID = 2
    private var pendingID: Int?
    private var ready = false
    private var pollTimer: Timer?
    private var responseTimeout: Timer?
    private var restartTimer: Timer?
    private var restartAttempt = 0
    private var isStopped = true
    private var generation = 0
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "local.alex.usage-topbar.network")
    private var pathIsSatisfied = false
    private let executableOverride: String?
    private let timeoutInterval: TimeInterval
    private let retryDelays: [TimeInterval]
    private let monitorsPath: Bool

    // Dependency injection keeps regression tests entirely local and credential-free.
    init(executable: String? = nil, timeout: TimeInterval = 10,
         retryDelays: [TimeInterval] = [1, 2, 5, 10, 30], monitorsPath: Bool = true) {
        self.executableOverride = executable
        self.timeoutInterval = timeout
        self.retryDelays = retryDelays.isEmpty ? [30] : retryDelays
        self.monitorsPath = monitorsPath
    }

    func start() {
        guard isStopped else { return }
        isStopped = false
        signal(SIGPIPE, SIG_IGN)
        onStatus?("Checking Codex…")
        onConnectionState?(.checking)
        if monitorsPath { startPathMonitoring() }
        launchProcess()
    }

    private func launchProcess() {
        guard !isStopped, process == nil else { return }
        restartTimer?.invalidate()
        restartTimer = nil
        guard let executable = executableOverride ?? findCodexBinary() else {
            fail("Codex not found", restart: true)
            return
        }
        buffer.removeAll(keepingCapacity: true)
        generation += 1
        let epoch = generation
        let child = Process()
        let stdinPipe = Pipe(), stdoutPipe = Pipe(), stderrPipe = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["app-server", "--stdio"]
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe
        output = stdoutPipe.fileHandleForReading
        errors = stderrPipe.fileHandleForReading
        output?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async {
                guard let self, self.generation == epoch, !self.isStopped else { return }
                self.consume(data)
            }
        }
        // Drain without persisting private app-server diagnostic content.
        errors?.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == epoch, !self.isStopped else { return }
                self.fail("Codex unavailable · retrying", restart: true)
            }
        }
        process = child
        input = stdinPipe.fileHandleForWriting
        do {
            try child.run()
            pendingID = 1
            armResponseTimeout()
            send(["method": "initialize", "id": 1, "params": [
                "clientInfo": ["name": "usage-topbar", "title": "Usage Topbar", "version": "0.3.1"],
                "capabilities": ["experimentalApi": true]
            ]])
        } catch {
            fail("Start failed · retrying", restart: true)
        }
    }

    private func disconnectProcess() {
        generation += 1
        pollTimer?.invalidate(); pollTimer = nil
        responseTimeout?.invalidate(); responseTimeout = nil
        pendingID = nil
        ready = false
        output?.readabilityHandler = nil
        errors?.readabilityHandler = nil
        output = nil; errors = nil
        try? input?.close(); input = nil
        let child = process
        process = nil
        child?.terminationHandler = nil
        if child?.isRunning == true {
            child?.terminate()
            // Bound shutdown of a wedged child; never target unrelated processes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let child, child.isRunning { kill(child.processIdentifier, SIGKILL) }
            }
        }
        buffer.removeAll(keepingCapacity: true)
    }

    func stop() {
        isStopped = true
        restartTimer?.invalidate(); restartTimer = nil
        pathMonitor?.cancel(); pathMonitor = nil
        pathIsSatisfied = false
        disconnectProcess()
    }

    func refresh() {
        guard !isStopped else { return }
        guard process?.isRunning == true else {
            fail("Codex unavailable · retrying", restart: true)
            return
        }
        guard ready, pendingID == nil else { return }
        let id = requestID
        requestID += 1
        pendingID = id
        armResponseTimeout()
        send(["method": "account/rateLimits/read", "id": id])
    }

    private func beginPolling() {
        ready = true
        refresh()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
        pollTimer?.tolerance = 3
    }

    private func startPathMonitoring() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            DispatchQueue.main.async {
                guard let self, let monitor, self.pathMonitor === monitor, !self.isStopped else { return }
                let wasSatisfied = self.pathIsSatisfied
                self.pathIsSatisfied = path.status == .satisfied
                if self.pathIsSatisfied {
                    if !wasSatisfied {
                        self.onConnectionState?(.checking)
                        self.refresh()
                    }
                } else {
                    self.onConnectionState?(.disconnected)
                    self.onStatus?("Offline · data unavailable")
                }
            }
        }
        monitor.start(queue: pathMonitorQueue)
    }

    private func armResponseTimeout() {
        responseTimeout?.invalidate()
        responseTimeout = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            self?.fail("Request timed out · retrying", restart: true)
        }
        if let responseTimeout { RunLoop.main.add(responseTimeout, forMode: .common) }
    }

    private func fail(_ status: String, restart: Bool) {
        responseTimeout?.invalidate(); responseTimeout = nil
        pendingID = nil
        onConnectionState?(.disconnected)
        onStatus?(status)
        if restart {
            disconnectProcess()
            scheduleRestart()
        }
    }

    private func scheduleRestart() {
        guard !isStopped, restartTimer == nil else { return }
        let delay = retryDelays[min(restartAttempt, retryDelays.count - 1)]
        restartAttempt = min(restartAttempt + 1, retryDelays.count - 1)
        restartTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.restartTimer = nil
            self?.launchProcess()
        }
        if let restartTimer { RunLoop.main.add(restartTimer, forMode: .common) }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        guard buffer.count <= 1_048_576 else {
            fail("Invalid response · retrying", restart: true)
            return
        }
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(object)
        }
    }

    private func handle(_ object: [String: Any]) {
        // Periodic reads are authoritative. Unsolicited/model-specific notifications
        // cannot cancel a request deadline or replace the Codex bucket.
        guard let id = object["id"] as? Int, id == pendingID else { return }
        responseTimeout?.invalidate(); responseTimeout = nil
        pendingID = nil
        if object["error"] != nil {
            fail("Codex request failed", restart: !ready)
            return
        }
        guard let result = object["result"] as? [String: Any] else {
            fail("Usage unavailable", restart: !ready)
            return
        }
        if id == 1 {
            send(["method": "initialized"])
            if process != nil { beginPolling() }
            return
        }
        guard let snapshot = parseReadResponse(result) else {
            fail("Usage unavailable", restart: false)
            return
        }
        guard !monitorsPath || pathIsSatisfied else {
            fail("Offline · data unavailable", restart: false)
            return
        }
        restartAttempt = 0
        onConnectionState?(.connected)
        onSnapshot?(snapshot)
    }

    func parseReadResponse(_ result: [String: Any]) -> UsageSnapshot? {
        var selected: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any] {
            selected = buckets["codex"] as? [String: Any]

        }
        if selected == nil { selected = result["rateLimits"] as? [String: Any] }
        guard var limits = selected else { return nil }
        if let limitID = limits["limitId"] as? String, limitID != "codex" { return nil }
        if limits["credits"] == nil {
            limits["credits"] = result["credits"]
        }
        return parseRateLimits(limits)
    }

    private func parseRateLimits(_ limits: [String: Any]) -> UsageSnapshot? {
        let primary = parseWindow(limits["primary"])
        let secondary = parseWindow(limits["secondary"])
        let windows = [primary, secondary].compactMap { $0 }
        guard let remaining = windows.map({ $0.remaining }).min() ?? creditFallback(limits) else { return nil }
        var detailParts: [String] = []
        if let limiting = windows.min(by: { $0.remaining < $1.remaining }) {
            detailParts.append(limiting.label)
            detailParts.append(contentsOf: windows
                .filter { $0.label != limiting.label && abs($0.remaining - remaining) >= 1 }
                .map { "\($0.label) \(Int($0.remaining.rounded()))%" })
        }

        if let credits = limits["credits"] as? [String: Any],
           let balance = number(credits["balance"]) {
            detailParts.append(formatPoints(balance))
        } else {
            detailParts.append("points --")
        }

        let nextReset = windows.min(by: { $0.remaining < $1.remaining })?.resetsAt
        return UsageSnapshot(
            remaining: remaining,
            detail: detailParts.joined(separator: "  ·  "),
            resetText: nextReset.map(formatReset)
        )
    }

    private func parseWindow(_ value: Any?) -> (remaining: Double, label: String, resetsAt: Double?)? {
        guard let window = value as? [String: Any], let used = number(window["usedPercent"]) else { return nil }
        let minutes = number(window["windowDurationMins"])
        let reset = number(window["resetsAt"])
        return (max(0, min(100, 100 - used)), durationLabel(minutes), reset)
    }

    private func creditFallback(_ limits: [String: Any]) -> Double? {
        guard let individual = limits["individualLimit"] as? [String: Any] else { return nil }
        return number(individual["remainingPercent"]).map { max(0, min(100, $0)) }
    }

    private func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber {
            guard CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
            return n.doubleValue
        }
        if let s = value as? String, let number = Double(s), number.isFinite { return number }
        return nil
    }

    private func durationLabel(_ minutes: Double?) -> String {
        guard let minutes, minutes > 0, minutes < 10_000_000 else { return "window" }
        if minutes >= 1440 {
            let days = Int((minutes / 1440).rounded())
            return days == 1 ? "1 day" : "\(days) days"
        }
        if minutes >= 60 {
            let hours = Int((minutes / 60).rounded())
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        }
        return "\(Int(minutes.rounded())) min"
    }

    private func formatReset(_ timestamp: Double) -> String {
        let seconds = min(315_360_000, timestamp - Date().timeIntervalSince1970)
        if seconds <= 0 { return "now" }
        if seconds < 3600 { return "\(max(1, Int(ceil(seconds / 60))))m" }
        if seconds < 86_400 { return "\(Int(ceil(seconds / 3600)))h" }
        return "\(Int(ceil(seconds / 86_400)))d"
    }

    private func formatPoints(_ value: Double) -> String {
        if abs(value) > 1_000_000_000 { return "points --" }
        if value >= 1_000 {
            let compact = String(format: "%.1fk", value / 1_000).replacingOccurrences(of: ".0k", with: "k")
            return "\(compact) points"
        }
        if value.rounded() == value { return "\(Int(value)) points" }
        return "\(String(format: "%.1f", value)) points"
    }

    private func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              var data = try? JSONSerialization.data(withJSONObject: object) else { return }
        data.append(0x0A)
        do { try input?.write(contentsOf: data) }
        catch { fail("Connection closed · retrying", restart: true) }
    }

    private func findCodexBinary() -> String? {
        if let override = ProcessInfo.processInfo.environment["CODEX_BINARY"],
           FileManager.default.isExecutableFile(atPath: override) { return override }
        let applicationURLs = ["com.openai.codex", "com.openai.chat"].compactMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
        let discovered = applicationURLs.flatMap { app in
            ["codex-cli/bin/codex", "codex"].map { app.appendingPathComponent("Contents/Resources/" + $0).path }
        }
        let candidates = discovered + [
            "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

struct NetworkBytes {
    let received: UInt64
    let sent: UInt64
}

enum NetworkRateCalculator {
    static func rates(previous: [String: NetworkBytes], current: [String: NetworkBytes],
                      elapsed: TimeInterval, maximumGap: TimeInterval) -> (Double, Double) {
        guard elapsed > 0, elapsed <= maximumGap else { return (0, 0) }
        var received: Double = 0, sent: Double = 0
        for (name, next) in current {
            guard let old = previous[name] else { continue }
            if next.received >= old.received { received += Double(next.received - old.received) }
            if next.sent >= old.sent { sent += Double(next.sent - old.sent) }
        }
        return (received / elapsed, sent / elapsed)
    }
}

final class SystemNetworkUsageMonitor {
    var onRates: ((_ downloadBytesPerSecond: Double, _ uploadBytesPerSecond: Double) -> Void)?
    private var sampleTimer: Timer?
    private var powerTimer: Timer?
    private var activeSampleInterval: Double = 2
    private var previousTotals: [String: NetworkBytes]?
    private var previousTime = ProcessInfo.processInfo.systemUptime

    func start() {
        guard sampleTimer == nil else { return }
        scheduleSampler(interval: preferredSampleInterval())
        powerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let preferred = self.preferredSampleInterval()
            if preferred != self.activeSampleInterval {
                self.sampleTimer?.invalidate()
                self.scheduleSampler(interval: preferred)
            }
        }
        powerTimer?.tolerance = 3
    }

    private func scheduleSampler(interval: Double) {
        activeSampleInterval = interval
        previousTotals = readExternalInterfaceTotals()
        previousTime = ProcessInfo.processInfo.systemUptime
        sampleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.sample() }
        sampleTimer?.tolerance = interval * 0.2
    }

    func stop() {
        sampleTimer?.invalidate(); sampleTimer = nil
        powerTimer?.invalidate(); powerTimer = nil
        previousTotals = nil
        onRates?(0, 0)
    }

    private func preferredSampleInterval() -> Double {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 5 }
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as? String else { return 2 }
        return source == (kIOPSBatteryPowerValue as String) ? 5 : 2
    }

    private func sample() {
        let now = ProcessInfo.processInfo.systemUptime
        let current = readExternalInterfaceTotals()
        defer { previousTotals = current; previousTime = now }
        guard let current, let previous = previousTotals else { onRates?(0, 0); return }
        let rates = NetworkRateCalculator.rates(previous: previous, current: current,
            elapsed: now - previousTime, maximumGap: activeSampleInterval * 3)
        onRates?(rates.0, rates.1)
    }

    private func readExternalInterfaceTotals() -> [String: NetworkBytes]? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(first) }
        var totals: [String: NetworkBytes] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let address = cursor {
            defer { cursor = address.pointee.ifa_next }
            guard let socketAddress = address.pointee.ifa_addr,
                  Int32(socketAddress.pointee.sa_family) == AF_LINK else { continue }
            let flags = Int32(bitPattern: address.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else { continue }
            let name = String(cString: address.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip"),
                  let rawData = address.pointee.ifa_data else { continue }
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            totals[name] = NetworkBytes(received: UInt64(data.ifi_ibytes), sent: UInt64(data.ifi_obytes))
        }
        return totals
    }
}

/// Screen coordinates are AppKit points, independent of Retina backing pixels.
enum OverlayPlacement {
    static func frame(window: CGRect, visibleScreens: [CGRect], scale: CGFloat) -> CGRect? {
        guard let screen = visibleScreens.max(by: {
            intersectionArea($0, window) < intersectionArea($1, window)
        }), intersectionArea(screen, window) > 0, screen.width >= 328 else { return nil }
        let x = min(max(window.minX, screen.minX), screen.maxX - 328)
        let y = window.maxY - 22
        // Preserve the attachment: if the information area cannot fit above the
        // window, keep the menu bar available instead of obscuring content/notch.
        guard y >= screen.minY, y + 74 <= screen.maxY else { return nil }
        let factor = max(1, scale)
        return CGRect(x: (x * factor).rounded() / factor,
                      y: (y * factor).rounded() / factor, width: 328, height: 74)
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct TrackedWindow {
        let bounds: CGRect
        let id: CGWindowID
        let orderIndex: Int
        let overlayOrderIndex: Int?
    }

    private let overlayWidth: CGFloat = 328
    private let overlayHeight: CGFloat = 74
    private var panel: NSPanel!
    private let overlayModel = OverlayModel()
    private var statusItem: NSStatusItem!
    private var rateClient: RateLimitClient?
    private var networkUsageMonitor: SystemNetworkUsageMonitor?
    private var positionTimer: Timer?
    private var mockTimer: Timer?
    private var mockRemaining = 68.0
    private var lastContrastSample = Date.distantPast
    private var currentDarkBackground: Bool?
    private var contrastSamplePending = false
    private var userHidden = false
    private var sleeping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationIcon()
        configureStatusItem()
        configurePanel()
        if CommandLine.arguments.contains("--mock") { startMock() } else { requestConsent() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        rateClient?.stop()
        networkUsageMonitor?.stop()
        positionTimer?.invalidate()
        mockTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func requestConsent() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "启动实时 Codex 用量监控？"
        alert.informativeText = "数据：Codex 用量、重置时间、积分、整机网速、窗口位置与 12×12 px 明暗样本。\n用途与操作：本次运行读取并显示这些数据、判断 Codex 连接和适配文字颜色，不保存内容。\n接收方：仅用量请求发送给 OpenAI；网速、窗口和明暗数据留在本机。"
        alert.addButton(withTitle: "启动")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "查看详情")
        alert.buttons[1].keyEquivalent = "\u{1b}"

        while true {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                startLive()
                return
            case .alertSecondButtonReturn:
                NSApp.terminate(nil)
                return
            default:
                showConsentDetails()
            }
        }
    }

    private func showConsentDetails() {
        let detailAlert = NSAlert()
        detailAlert.icon = NSApp.applicationIconImage
        detailAlert.messageText = "本次实时模式的数据说明"
        detailAlert.informativeText = "数据：用量百分比、重置时间、积分余额、Mac 活跃外部网卡的累计上下行字节数、ChatGPT 窗口位置、顶栏下方 12×12 px 区域的平均明暗值，以及读取 Codex 用量时产生的公网 IP、连接时间和标准 TLS 元数据。\n用途：绘制、定位浮层，显示整机实时网络速率、确认 Codex 服务连接，并自动选择高对比度字体。\n操作：每 30 秒通过本地 Codex app-server 读取 account/rateLimits，并以该已认证请求的结果显示 Codex 连接状态；本机读取网卡累计字节计数并计算增量（接电每 2 秒，电池或低电量模式每 5 秒）；本机枚举窗口几何信息并定期采样极小颜色区域，不读取网络内容或文字。\n接收方：OpenAI 接收已登录账户的用量读取请求；没有第三方接收网卡统计、颜色或窗口数据，它们只留在本机。\n\n本次启动不会保存用量快照、连接状态、网卡统计、颜色样本或截图。"
        detailAlert.addButton(withTitle: "返回")
        detailAlert.runModal()
    }

    private func configureApplicationIcon() {
        guard let url = Bundle.main.url(forResource: "UsageTopbar", withExtension: "icns"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = icon
    }

    private func configurePanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .normal
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // NSWindow shadows are rectangular even when the SwiftUI content is
        // not. Disabling it prevents a black box around the rounded tab.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let frame = NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight)
        let hostingView = NSHostingView(rootView: UsageEdgeTabView(model: overlayModel))
        hostingView.frame = frame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "∞ --%"
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusItem.button?.toolTip = "Usage Topbar — Codex remaining usage"
        let menu = NSMenu()
        menu.addItem(withTitle: "立即刷新", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(withTitle: "显示/隐藏浮层", action: #selector(togglePanel), keyEquivalent: "h")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Usage Topbar", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func startLive() {
        panel.orderOut(nil)
        startPositionTracking()
        startActivationTracking()
        let client = RateLimitClient()
        client.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in self?.apply(snapshot) }
        }
        client.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.statusItem.button?.title = "∞ --%"
                self?.overlayModel.snapshot = .unavailable(status)
            }
        }
        client.onConnectionState = { [weak self] state in
            Task { @MainActor in
                self?.overlayModel.connectionState = state
            }
        }
        rateClient = client
        client.start()
        let usageMonitor = SystemNetworkUsageMonitor()
        usageMonitor.onRates = { [weak self] download, upload in
            Task { @MainActor in
                self?.overlayModel.downloadBytesPerSecond = download
                self?.overlayModel.uploadBytesPerSecond = upload
            }
        }
        networkUsageMonitor = usageMonitor
        usageMonitor.start()
        NSApp.deactivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updatePanelVisibility(for: NSWorkspace.shared.frontmostApplication)
        }
    }

    private func startMock() {
        panel.orderFrontRegardless()
        positionFallback()
        overlayModel.connectionState = .connected
        overlayModel.downloadBytesPerSecond = 24 * 1_024
        overlayModel.uploadBytesPerSecond = 3 * 1_024
        apply(.mock)
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.mockRemaining -= 1
            if self.mockRemaining < 12 { self.mockRemaining = 88 }
            self.apply(UsageSnapshot(remaining: self.mockRemaining, detail: "1 day  ·  120 points", resetText: "3h"))
        }
    }

    private func startPositionTracking() {
        positionTimer?.invalidate()
        synchronizePanelVisibility()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.synchronizePanelVisibility()
        }
        positionTimer?.tolerance = 0.1
    }

    private func synchronizePanelVisibility() {
        updatePanelVisibility(for: NSWorkspace.shared.frontmostApplication)
    }

    private func startActivationTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func willSleep(_ notification: Notification) {
        sleeping = true
        panel.orderOut(nil)
        positionTimer?.invalidate(); positionTimer = nil
        rateClient?.stop()
        networkUsageMonitor?.stop()
        overlayModel.snapshot = .unavailable("Sleeping · data unavailable")
        overlayModel.connectionState = .checking
        statusItem.button?.title = "∞ --%"
    }

    @objc private func didWake(_ notification: Notification) {
        sleeping = false
        rateClient?.start()
        networkUsageMonitor?.start()
        startPositionTracking()
    }

    @objc private func screensChanged(_ notification: Notification) {
        currentDarkBackground = nil
        lastContrastSample = .distantPast
        synchronizePanelVisibility()
    }

    @objc private func workspaceApplicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updatePanelVisibility(for: application)
    }

    private func updatePanelVisibility(for application: NSRunningApplication?) {
        guard let application,
              !userHidden, !sleeping,
              isCodexApplication(application) else {
            panel.orderOut(nil)
            return
        }
        showPanelBehindCodex(for: application)
    }

    private func isCodexApplication(_ application: NSRunningApplication?) -> Bool {
        guard let application else { return false }
        if ["ChatGPT", "Codex"].contains(application.localizedName ?? "") { return true }
        guard let bundleIdentifier = application.bundleIdentifier else { return false }
        return bundleIdentifier == "com.openai.codex"
            || bundleIdentifier == "com.openai.chat"
            || bundleIdentifier.hasPrefix("com.openai.chatgpt")
    }

    private func apply(_ snapshot: UsageSnapshot) {
        overlayModel.snapshot = snapshot
        statusItem.button?.title = "∞ \(snapshot.percentageText)"
    }

    private func positionPanel(for window: TrackedWindow) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let bounds = window.bounds
        let converted = CGRect(x: bounds.minX, y: primary.frame.maxY - bounds.maxY,
                               width: bounds.width, height: bounds.height)
        let screens = NSScreen.screens
        let screen = screens.max {
            let a = $0.frame.intersection(converted), b = $1.frame.intersection(converted)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }
        guard let frame = OverlayPlacement.frame(window: converted,
            visibleScreens: screens.map { screen in
                let safeTop = screen.frame.maxY - screen.safeAreaInsets.top
                return screen.visibleFrame.intersection(CGRect(x: screen.frame.minX, y: screen.frame.minY,
                    width: screen.frame.width, height: safeTop - screen.frame.minY))
            },
            scale: screen?.backingScaleFactor ?? 1) else { return false }
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if panel.isVisible { updateContrast(window: window, panelX: frame.minX) }
        return true
    }

    private func showPanelBehindCodex(for application: NSRunningApplication) {
        guard let window = chatGPTWindow(for: application) else {
            panel.orderOut(nil)
            return
        }
        guard positionPanel(for: window) else { panel.orderOut(nil); return }
        let overlayIsBehindCodex = window.overlayOrderIndex.map { $0 > window.orderIndex } ?? false
        if !panel.isVisible || !overlayIsBehindCodex {
            panel.order(.below, relativeTo: Int(window.id))
        }
    }

    private func positionFallback() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: frame.minX + 18,
            y: frame.maxY - overlayHeight
        ))
    }

    private func chatGPTWindow(for application: NSRunningApplication) -> TrackedWindow? {
        let processIdentifier = application.processIdentifier
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let panelWindowNumber = panel.windowNumber
        let overlayOrderIndex = info.firstIndex { item in
            (item[kCGWindowNumber as String] as? NSNumber)?.intValue == panelWindowNumber
        }
        return info.enumerated().compactMap { orderIndex, item -> TrackedWindow? in
            guard let ownerPID = item[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == processIdentifier,
                  (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let windowNumber = item[kCGWindowNumber as String] as? NSNumber,
                  let dictionary = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary),
                  rect.width >= 328, rect.height >= 200 else { return nil }
            return TrackedWindow(
                bounds: rect,
                id: CGWindowID(windowNumber.uint32Value),
                orderIndex: orderIndex,
                overlayOrderIndex: overlayOrderIndex
            )
        }.first
    }

    private func updateContrast(window: TrackedWindow, panelX: CGFloat) {
        guard !contrastSamplePending,
              Date().timeIntervalSince(lastContrastSample) >= 3 else { return }
        lastContrastSample = Date()

        let fallback = fallbackDarkAppearance()
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else {
            applyContrast(isDarkBackground: fallback)
            return
        }

        contrastSamplePending = true
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, _ in
            guard let self,
                  let target = content?.windows.first(where: { $0.windowID == window.id }) else {
                DispatchQueue.main.async { [weak self] in
                    self?.finishContrastSample(luminance: nil, fallback: fallback)
                }
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: target)
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(
                x: max(0, min(window.bounds.width - 12, panelX - window.bounds.minX + self.overlayWidth / 2 - 6)),
                y: 5,
                width: 12,
                height: 12
            )
            configuration.width = 24
            configuration.height = 24
            configuration.showsCursor = false
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { [weak self] image, _ in
                let luminance = image.flatMap { self?.averageLuminance(of: $0) }
                DispatchQueue.main.async { [weak self] in
                    self?.finishContrastSample(luminance: luminance, fallback: fallback)
                }
            }
        }
    }

    private func finishContrastSample(luminance: CGFloat?, fallback: Bool) {
        contrastSamplePending = false
        guard let luminance else {
            applyContrast(isDarkBackground: fallback)
            return
        }
        var isDark = fallback
        if luminance < 0.44 { isDark = true }
        if luminance > 0.56 { isDark = false }
        if (0.44...0.56).contains(luminance), let currentDarkBackground {
            isDark = currentDarkBackground
        }
        applyContrast(isDarkBackground: isDark)
    }

    private func averageLuminance(of image: CGImage) -> CGFloat? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else { return nil }
        var total: CGFloat = 0
        var count: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                total += 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
                count += 1
            }
        }
        return count > 0 ? total / count : nil
    }

    private func fallbackDarkAppearance() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func applyContrast(isDarkBackground: Bool) {
        guard currentDarkBackground != isDarkBackground else { return }
        currentDarkBackground = isDarkBackground
        overlayModel.isDarkBackground = isDarkBackground
    }

    @objc private func refreshNow() { rateClient?.refresh() }
    @objc private func togglePanel() {
        if panel.isVisible {
            userHidden = true
            panel.orderOut(nil)
        } else {
            userHidden = false
            updatePanelVisibility(for: NSWorkspace.shared.frontmostApplication)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor
func renderPreview(to path: String) throws {
    let model = OverlayModel()
    model.snapshot = .mock
    model.isDarkBackground = true
    model.connectionState = .connected
    model.downloadBytesPerSecond = 24 * 1_024
    model.uploadBytesPerSecond = 3 * 1_024
    let renderer = ImageRenderer(content: UsageEdgeTabPreview(model: model))
    renderer.proposedSize = ProposedViewSize(width: 328, height: 74)
    renderer.scale = 2
    guard let image = renderer.cgImage else {
        throw NSError(domain: "UsageTopbar", code: 1)
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "UsageTopbar", code: 2)
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

if let index = CommandLine.arguments.firstIndex(of: "--render-preview"),
   CommandLine.arguments.indices.contains(index + 1) {
    do {
        try MainActor.assumeIsolated {
            try renderPreview(to: CommandLine.arguments[index + 1])
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Preview failed: \(error)\n".utf8))
        exit(1)
    }
}

if CommandLine.arguments.contains("--benchmark-network") {
    var sampleCount = 0
    let monitor = SystemNetworkUsageMonitor()
    monitor.onRates = { _, _ in sampleCount += 1 }
    monitor.start()
    RunLoop.current.run(until: Date().addingTimeInterval(12))
    monitor.stop()
    print("network samples: \(sampleCount)")
    exit(sampleCount > 0 ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
