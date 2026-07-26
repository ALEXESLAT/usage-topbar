import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOKit.ps
import Network
import ScreenCaptureKit
import SwiftUI

struct UsageSnapshot {
    let remaining: Double
    let detail: String
    let resetText: String?

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
        case .checking: return "正在检查 GPT 网络连接"
        case .connected: return "GPT 网络已连接"
        case .disconnected: return "GPT 网络不可用"
        }
    }
}

final class OverlayModel: ObservableObject {
    @Published var snapshot: UsageSnapshot = .mock
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
        max(0, min(100, model.snapshot.remaining))
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
                Text("NET")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
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
        .frame(width: 38, alignment: .trailing)
        .padding(.top, 9)
        .padding(.trailing, 12)
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

            Text("\(Int(remaining.rounded()))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryColor)
                .frame(width: 47, alignment: .leading)

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
        .padding(.trailing, 42)
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
                "Codex remaining usage \(Int(remaining.rounded())) percent. \(accessibilityDetail). \(model.connectionState.label). \(throughputAccessibilityText)"
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
    private var buffer = Data()
    private var requestID = 2
    private var pollTimer: Timer?
    private var responseTimeout: Timer?
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "local.alex.usage-topbar.network")
    private let probeQueue = DispatchQueue(label: "local.alex.usage-topbar.openai-probe")
    private var pathMonitorStarted = false
    private var hasConnectedSnapshot = false
    private var pathIsSatisfied = false
    private var probeTimer: Timer?
    private var probeTimeout: Timer?
    private var probeConnection: NWConnection?
    private var probeID: UUID?

    func start() {
        startPathMonitoring()
        guard let executable = findCodexBinary() else {
            onConnectionState?(.disconnected)
            onStatus?("Codex not found")
            return
        }

        let child = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["app-server", "--stdio"]
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try child.run()
            process = child
            input = stdinPipe.fileHandleForWriting
            child.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.responseTimeout?.invalidate()
                    self?.responseTimeout = nil
                    self?.onConnectionState?(.disconnected)
                    self?.onStatus?("GPT network unavailable")
                }
            }
            send([
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": ["name": "usage-topbar", "title": "Usage Topbar", "version": "0.2.5"],
                    "capabilities": ["experimentalApi": true, "requestAttestation": false]
                ]
            ])
        } catch {
            onConnectionState?(.disconnected)
            onStatus?("Start failed")
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        responseTimeout?.invalidate()
        responseTimeout = nil
        probeTimer?.invalidate()
        probeTimer = nil
        probeTimeout?.invalidate()
        probeTimeout = nil
        probeID = nil
        probeConnection?.cancel()
        probeConnection = nil
        if pathMonitorStarted {
            pathMonitor.cancel()
            pathMonitorStarted = false
        }
        input?.closeFile()
        if process?.isRunning == true { process?.terminate() }
        process = nil
    }

    func refresh() {
        guard process?.isRunning == true else {
            onConnectionState?(.disconnected)
            return
        }
        let id = requestID
        requestID += 1
        send(["method": "account/rateLimits/read", "id": id])
        armResponseTimeout()
    }

    private func beginPolling() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func startPathMonitoring() {
        guard !pathMonitorStarted else { return }
        pathMonitorStarted = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                if path.status == .satisfied {
                    let justReconnected = !self.pathIsSatisfied
                    self.pathIsSatisfied = true
                    self.onConnectionState?(self.hasConnectedSnapshot ? .connected : .checking)
                    if self.process?.isRunning == true && !self.hasConnectedSnapshot {
                        self.refresh()
                    }
                    if justReconnected {
                        self.scheduleProbe(after: 0.1)
                    }
                } else {
                    self.pathIsSatisfied = false
                    self.probeTimer?.invalidate()
                    self.probeTimer = nil
                    self.cancelActiveProbe()
                    self.markDisconnected()
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func scheduleProbe(after delay: TimeInterval? = nil) {
        guard pathIsSatisfied else { return }
        probeTimer?.invalidate()
        probeTimer = Timer.scheduledTimer(
            withTimeInterval: delay ?? preferredProbeInterval(),
            repeats: false
        ) { [weak self] _ in
            self?.probeTimer = nil
            self?.runOpenAIProbe()
        }
    }

    private func runOpenAIProbe() {
        guard pathIsSatisfied, probeConnection == nil else { return }
        let id = UUID()
        probeID = id
        let tls = NWProtocolTLS.Options()
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 2
        let connection = NWConnection(
            host: NWEndpoint.Host("chatgpt.com"),
            port: NWEndpoint.Port(rawValue: 443)!,
            using: NWParameters(tls: tls, tcp: tcp)
        )
        probeConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self, self.probeID == id else { return }
                switch state {
                case .ready:
                    self.finishProbe(id: id, succeeded: true)
                case .failed:
                    self.finishProbe(id: id, succeeded: false)
                default:
                    break
                }
            }
        }
        probeTimeout?.invalidate()
        probeTimeout = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.finishProbe(id: id, succeeded: false)
        }
        connection.start(queue: probeQueue)
    }

    private func finishProbe(id: UUID, succeeded: Bool) {
        guard probeID == id else { return }
        probeTimeout?.invalidate()
        probeTimeout = nil
        probeID = nil
        probeConnection?.stateUpdateHandler = nil
        probeConnection?.cancel()
        probeConnection = nil
        if succeeded {
            onConnectionState?(.connected)
        } else {
            onConnectionState?(.disconnected)
        }
        scheduleProbe()
    }

    private func cancelActiveProbe() {
        probeTimeout?.invalidate()
        probeTimeout = nil
        probeID = nil
        probeConnection?.stateUpdateHandler = nil
        probeConnection?.cancel()
        probeConnection = nil
    }

    private func preferredProbeInterval() -> TimeInterval {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 15 }
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
                as? String else { return 5 }
        return source == (kIOPSBatteryPowerValue as String) ? 15 : 5
    }

    private func armResponseTimeout() {
        responseTimeout?.invalidate()
        responseTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.responseTimeout = nil
            self?.onConnectionState?(.disconnected)
            self?.onStatus?("GPT network unavailable")
        }
    }

    private func markConnected() {
        responseTimeout?.invalidate()
        responseTimeout = nil
        hasConnectedSnapshot = true
        onConnectionState?(.connected)
    }

    private func markDisconnected() {
        responseTimeout?.invalidate()
        responseTimeout = nil
        hasConnectedSnapshot = false
        onConnectionState?(.disconnected)
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            handle(object)
        }
    }

    private func handle(_ object: [String: Any]) {
        if (object["id"] as? NSNumber)?.intValue == 1, object["result"] != nil {
            send(["method": "initialized"])
            beginPolling()
            return
        }

        if let result = object["result"] as? [String: Any], let snapshot = parseReadResponse(result) {
            markConnected()
            onSnapshot?(snapshot)
            return
        }

        if object["method"] as? String == "account/rateLimits/updated",
           let params = object["params"] as? [String: Any],
           let limits = params["rateLimits"] as? [String: Any],
           let snapshot = parseRateLimits(limits) {
            markConnected()
            onSnapshot?(snapshot)
            return
        }

        if object["error"] != nil {
            markDisconnected()
            onStatus?("GPT network unavailable")
        }
    }

    private func parseReadResponse(_ result: [String: Any]) -> UsageSnapshot? {
        var selected: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any] {
            selected = buckets["codex"] as? [String: Any]
            if selected == nil { selected = buckets.values.compactMap { $0 as? [String: Any] }.first }
        }
        if selected == nil { selected = result["rateLimits"] as? [String: Any] }
        guard var limits = selected else { return nil }
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
            detailParts.append(remainingDaysLabel(until: limiting.resetsAt))
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

        let nextReset = windows.compactMap { $0.resetsAt }.min()
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
        return number(individual["remainingPercent"])
    }

    private func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func durationLabel(_ minutes: Double?) -> String {
        guard let minutes else { return "window" }
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
        let seconds = timestamp - Date().timeIntervalSince1970
        if seconds <= 0 { return "now" }
        if seconds < 3600 { return "\(max(1, Int(ceil(seconds / 60))))m" }
        if seconds < 86_400 { return "\(Int(ceil(seconds / 3600)))h" }
        return "\(Int(ceil(seconds / 86_400)))d"
    }

    private func remainingDaysLabel(until timestamp: Double?) -> String {
        guard let timestamp else { return "reset --" }
        let seconds = max(0, timestamp - Date().timeIntervalSince1970)
        let days = max(1, Int(ceil(seconds / 86_400)))
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func formatPoints(_ value: Double) -> String {
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
        input?.write(data)
    }

    private func findCodexBinary() -> String? {
        if let override = ProcessInfo.processInfo.environment["CODEX_BINARY"],
           FileManager.default.isExecutableFile(atPath: override) { return override }
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

final class SystemNetworkUsageMonitor {
    var onRates: ((_ downloadBytesPerSecond: Double, _ uploadBytesPerSecond: Double) -> Void)?

    private struct Totals {
        let received: UInt64
        let sent: UInt64
    }

    private var sampleTimer: Timer?
    private var powerTimer: Timer?
    private var activeSampleInterval: Double = 2
    private var previousTotals: Totals?

    func start() {
        guard sampleTimer == nil, powerTimer == nil else { return }
        scheduleSampler(interval: preferredSampleInterval())
        powerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshSamplingInterval()
        }
    }

    private func scheduleSampler(interval: Double) {
        activeSampleInterval = interval
        previousTotals = readExternalInterfaceTotals()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        powerTimer?.invalidate()
        powerTimer = nil
        previousTotals = nil
        onRates?(0, 0)
    }

    private func refreshSamplingInterval() {
        let preferred = preferredSampleInterval()
        guard preferred != activeSampleInterval else { return }
        sampleTimer?.invalidate()
        sampleTimer = nil
        scheduleSampler(interval: preferred)
    }

    private func preferredSampleInterval() -> Double {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 5 }
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
                as? String else { return 2 }
        return source == (kIOPSBatteryPowerValue as String) ? 5 : 2
    }

    private func sample() {
        guard let current = readExternalInterfaceTotals() else {
            previousTotals = nil
            onRates?(0, 0)
            return
        }
        defer { previousTotals = current }
        guard let previous = previousTotals else { return }
        let received = current.received >= previous.received
            ? current.received - previous.received
            : 0
        let sent = current.sent >= previous.sent
            ? current.sent - previous.sent
            : 0
        onRates?(
            Double(received) / activeSampleInterval,
            Double(sent) / activeSampleInterval
        )
    }

    private func readExternalInterfaceTotals() -> Totals? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(first) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let address = cursor {
            defer { cursor = address.pointee.ifa_next }
            guard let socketAddress = address.pointee.ifa_addr,
                  Int32(socketAddress.pointee.sa_family) == AF_LINK else { continue }

            let flags = Int32(bitPattern: address.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_RUNNING != 0,
                  flags & IFF_LOOPBACK == 0 else { continue }

            let name = String(cString: address.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip"),
                  let rawData = address.pointee.ifa_data else { continue }
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            received &+= UInt64(data.ifi_ibytes)
            sent &+= UInt64(data.ifi_obytes)
        }
        return Totals(received: received, sent: sent)
    }
}

final class TLSProbeBenchmark {
    private let queue = DispatchQueue(label: "local.alex.usage-topbar.probe-benchmark")
    private var connection: NWConnection?
    private var timeout: Timer?
    private var attemptID: UUID?
    private(set) var successes = 0
    private(set) var failures = 0

    func startAttempt() {
        guard connection == nil else { return }
        let id = UUID()
        attemptID = id
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 2
        let candidate = NWConnection(
            host: NWEndpoint.Host("chatgpt.com"),
            port: NWEndpoint.Port(rawValue: 443)!,
            using: NWParameters(tls: NWProtocolTLS.Options(), tcp: tcp)
        )
        connection = candidate
        candidate.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self, self.attemptID == id else { return }
                switch state {
                case .ready: self.finish(id: id, succeeded: true)
                case .failed: self.finish(id: id, succeeded: false)
                default: break
                }
            }
        }
        timeout = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.finish(id: id, succeeded: false)
        }
        candidate.start(queue: queue)
    }

    private func finish(id: UUID, succeeded: Bool) {
        guard attemptID == id else { return }
        timeout?.invalidate()
        timeout = nil
        attemptID = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        if succeeded { successes += 1 } else { failures += 1 }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct TrackedWindow {
        let bounds: CGRect
        let id: CGWindowID
    }

    private let overlayWidth: CGFloat = 328
    private let overlayHeight: CGFloat = 74
    private let edgeOverlap: CGFloat = 22
    private let windowLeadingInset: CGFloat = 0
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
    }

    private func requestConsent() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "允许显示实时 Codex 剩余用量？"
        alert.informativeText = "数据：用量百分比、重置时间、积分余额、Mac 活跃外部网卡的累计上下行字节数、ChatGPT 窗口位置、顶栏下方 12×12 px 区域的平均明暗值，以及连接 OpenAI 时产生的公网 IP、连接时间和标准 TLS 元数据。\n用途：绘制、定位浮层，显示整机实时网络速率、快速判断 GPT 网络连接，并自动选择高对比度字体。\n操作：每 30 秒通过本地 Codex app-server 读取 account/rateLimits；对 chatgpt.com:443 做不含 HTTP 正文或凭证的 TLS 握手（接电每 5 秒，电池或低电量模式每 15 秒，2 秒超时）；本机读取网卡累计字节计数并计算增量（接电每 2 秒，电池或低电量模式每 5 秒）；本机枚举窗口几何信息并定期采样极小颜色区域，不读取网络内容或文字。\n接收方：OpenAI 接收已登录账户的用量读取请求和 TLS 握手元数据；没有第三方接收网卡统计、颜色或窗口数据，它们只留在本机。\n\n本次启动不会保存用量快照、连通测试、网卡统计、颜色样本或截图。"
        alert.addButton(withTitle: "同意并启动")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn { startLive() } else { NSApp.terminate(nil) }
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
                self?.overlayModel.snapshot = UsageSnapshot(remaining: 0, detail: status, resetText: nil)
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
        positionPanel()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.positionPanel()
        }
    }

    private func startActivationTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func workspaceApplicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updatePanelVisibility(for: application)
    }

    private func updatePanelVisibility(for application: NSRunningApplication?) {
        guard application?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        guard !userHidden, isCodexApplication(application) else {
            panel.orderOut(nil)
            return
        }
        showPanelBehindCodex()
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
        statusItem.button?.title = "∞ \(Int(snapshot.remaining.rounded()))%"
    }

    private func positionPanel() {
        guard let window = chatGPTWindow() else {
            positionFallback()
            return
        }
        positionPanel(for: window)
    }

    private func positionPanel(for window: TrackedWindow) {
        let bounds = window.bounds
        let primaryTop = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
        let windowTop = primaryTop - bounds.minY
        let x = bounds.minX + windowLeadingInset
        // The lower 22 points sit behind Codex. With a 10-point bottom
        // radius, the left edge remains vertical for 12 points below the
        // meeting line before it starts rounding inward.
        let preferredY = windowTop - edgeOverlap
        let screen = NSScreen.screens.first {
            $0.frame.minX <= bounds.midX && bounds.midX <= $0.frame.maxX
        } ?? NSScreen.main
        let maximumY = (screen?.frame.maxY ?? primaryTop) - overlayHeight
        let y = min(preferredY, maximumY)
        panel.setFrameOrigin(NSPoint(
            x: x,
            y: y
        ))
        if panel.isVisible {
            updateContrast(window: window, panelX: x)
        }
    }

    private func showPanelBehindCodex() {
        guard let window = chatGPTWindow() else {
            panel.orderOut(nil)
            return
        }
        positionPanel(for: window)
        panel.order(.below, relativeTo: Int(window.id))
    }

    private func positionFallback() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: frame.minX + 18,
            y: frame.maxY - overlayHeight
        ))
    }

    private func chatGPTWindow() -> TrackedWindow? {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        return info.compactMap { item -> TrackedWindow? in
            guard let owner = item[kCGWindowOwnerName as String] as? String,
                  ["ChatGPT", "Codex"].contains(owner),
                  (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let windowNumber = item[kCGWindowNumber as String] as? NSNumber,
                  let dictionary = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary),
                  rect.width > 500, rect.height > 300 else { return nil }
            return TrackedWindow(bounds: rect, id: CGWindowID(windowNumber.uint32Value))
        }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }

    private func updateContrast(window: TrackedWindow, panelX: CGFloat) {
        guard !contrastSamplePending,
              Date().timeIntervalSince(lastContrastSample) >= 1.5 else { return }
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
                x: panelX - window.bounds.minX + self.overlayWidth / 2 - 6,
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

if CommandLine.arguments.contains("--benchmark-connectivity") {
    let benchmark = TLSProbeBenchmark()
    for second in [0.0, 4.0, 8.0] {
        Timer.scheduledTimer(withTimeInterval: second + 0.1, repeats: false) { _ in
            benchmark.startAttempt()
        }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(12))
    print("TLS probe successes: \(benchmark.successes), failures: \(benchmark.failures)")
    exit(benchmark.successes >= 2 ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
