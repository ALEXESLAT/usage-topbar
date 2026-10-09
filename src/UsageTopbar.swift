import AppKit
import CoreGraphics
import CoreText
import Combine
import Darwin
import Foundation
import IOKit.ps
import Network
import ScreenCaptureKit
import ServiceManagement
import SwiftUI

// Official app-server RateLimitResetCreditsSummary/RateLimitResetCredit fields.
// availableCount is authoritative; the detail list may be capped and is NOT a count.
struct ResetCardDisplay: Equatable {
    var count: Int?
    var expiryText: String
    var accessibilityText: String
    var countText: String { count.map { $0 > 99 ? "99+" : "\($0)" } ?? "--" }
    static let unknown = ResetCardDisplay(count: nil, expiryText: "Exp. --", accessibilityText: "重置卡数量及到期时间未知")
}

struct ResetCards: Equatable {
    struct Card: Equatable {
        let available: Bool
        let expiresAt: Double?
        let expirationKnown: Bool
    }
    let availableCount: Int
    let credits: [Card]?

    static func parse(_ value: Any?) -> ResetCards? {
        guard let value = value as? [String: Any],
              let count = value["availableCount"] as? NSNumber,
              CFGetTypeID(count) != CFBooleanGetTypeID(), count.doubleValue.isFinite,
              count.doubleValue >= 0, count.doubleValue <= 1_000_000,
              count.doubleValue.rounded(.down) == count.doubleValue else { return nil }
        var cards: [Card]?
        if let rows = value["credits"] as? [[String: Any]] {
            var ids = Set<String>()
            var validRows = true
            cards = rows.map { row in
                if let id = row["id"] as? String, !id.isEmpty, ids.insert(id).inserted {} else { validRows = false }
                let raw = row["expiresAt"]
                // Protocol specifies epoch SECONDS; null explicitly means no expiry.
                let number = raw as? NSNumber
                let expiry = number.flatMap { n -> Double? in
                    guard CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite,
                          n.doubleValue > 0, n.doubleValue < 4_102_444_800 else { return nil }
                    return n.doubleValue
                }
                return Card(available: row["status"] as? String == "available" && row["resetType"] as? String == "codexRateLimits",
                            expiresAt: expiry, expirationKnown: raw is NSNull || expiry != nil)
            }
            if !validRows { cards = nil }
        }
        return ResetCards(availableCount: count.intValue, credits: cards)
    }

    func display(at now: Date, timeZone: TimeZone = .current) -> ResetCardDisplay {
        if availableCount == 0 { return ResetCardDisplay(count: 0, expiryText: "Exp. --", accessibilityText: "可用重置卡 0 张") }
        let available = credits?.filter { $0.available } ?? []
        let complete = available.count == availableCount && credits?.count == availableCount
        let active = available.filter { ($0.expiresAt ?? .infinity) > now.timeIntervalSince1970 }
        // Reconcile locally expired cards only with a complete, consistent snapshot.
        // A capped list cannot establish either the exact current count or earliest expiry.
        if active.count != available.count && !complete { return .unknown }
        let count = complete ? active.count : availableCount
        if count == 0 { return ResetCardDisplay(count: 0, expiryText: "Exp. --", accessibilityText: "可用重置卡 0 张，已知卡均已过期") }
        guard complete, active.allSatisfy({ $0.expirationKnown }) else {
            return ResetCardDisplay(count: count, expiryText: "Exp. --", accessibilityText: "可用重置卡 \(count) 张，最近到期时间未知，详情可能缺失或不完整")
        }
        guard let earliest = active.compactMap({ $0.expiresAt }).min() else {
            return ResetCardDisplay(count: count, expiryText: "Exp. none", accessibilityText: "可用重置卡 \(count) 张，均无到期限制")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM/dd"
        let date = Date(timeIntervalSince1970: earliest)
        let short = formatter.string(from: date)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return ResetCardDisplay(count: count, expiryText: "Exp. " + short,
                                accessibilityText: "可用重置卡 \(count) 张，最近一张到期于 " + formatter.string(from: date))
    }
}

struct UsageSnapshot: Equatable {
    var remaining: Double?
    var detail: String
    var resetText: String?
    var resetsAt: Double? = nil
    var resetDetailSuffix: String? = nil
    var resetCards: ResetCards? = nil
    var resetCardDisplay: ResetCardDisplay = .unknown

    /// Recompute cached display text from the absolute deadline, never a window length.
    func refreshed(at now: Date = Date()) -> UsageSnapshot {
        var result = self
        result.resetCardDisplay = resetCards?.display(at: now) ?? .unknown
        guard let resetsAt, let suffix = resetDetailSuffix else { return result }
        let seconds = resetsAt - now.timeIntervalSince1970
        guard seconds > 0 else {
            result.remaining = nil
            result.detail = "Reset pending · " + suffix
            result.resetText = "now"
            return result
        }
        result.detail = Self.countdown(seconds) + " left · " + suffix
        result.resetText = Self.compactCountdown(seconds)
        return result
    }

    static func compactCountdown(_ seconds: Double) -> String {
        if seconds >= 10 * 86400 { return "\(Int(seconds / 86400))d" }
        if seconds >= 86400 { return countdown(seconds) }
        if seconds >= 3600 { return "\(Int(seconds / 3600))h" }
        return countdown(seconds)
    }

    static func countdown(_ seconds: Double) -> String {
        // Whole days/hours avoid inflating 5 days + 1 hour into "6d".
        // Keep sub-minute positive intervals distinct from a deadline that has passed.
        if seconds < 60 { return "<1m" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 {
            let rest = minutes % 60
            return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)m"
        }
        let days = hours / 24, rest = hours % 24
        return rest == 0 ? "\(days)d" : "\(days)d\(rest)h"
    }

    var percentageText: String {
        guard let remaining, remaining.isFinite else { return "--%" }
        return RecoveryFill.text(max(0, min(100, remaining)), animating: false)
    }

    static func unavailable(_ reason: String) -> UsageSnapshot {
        UsageSnapshot(remaining: nil, detail: reason, resetText: nil)
    }

    static var mock: UsageSnapshot {
        UsageSnapshot(remaining: 68, detail: "", resetText: nil,
                      resetsAt: Date().timeIntervalSince1970 + 3 * 3600,
                      resetDetailSuffix: "120 points").refreshed()
    }
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

/// Raw snapshots remain current, but only observable presentation changes invalidate SwiftUI.
private struct OverlaySnapshotPresentation: Equatable {
    let remaining: Double?
    let detail: String
    let resetText: String?
    let points: String
    let cards: ResetCardDisplay

    init(_ snapshot: UsageSnapshot) {
        remaining = snapshot.remaining // Preserve sub-percent progress precision.
        detail = snapshot.detail       // Includes information spoken by accessibility.
        resetText = snapshot.resetText
        points = OverlayLabels.points(snapshot)
        cards = snapshot.resetCardDisplay
    }
}

/// A one-entry cache for the fixed system fonts; network/color changes reuse the result.
final class QuotaTextMetricsCache {
    private struct Key: Equatable { let percentage: String; let points: String }
    private var key: Key?
    private var value: CGFloat = 0
    private let measure: (String, String) -> CGFloat
    private static let percentageFont = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
    private static let pointsFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

    init(measure: @escaping (String, String) -> CGFloat = QuotaTextMetricsCache.measureInset) {
        self.measure = measure
    }

    func inset(percentage: String, points: String) -> CGFloat {
        let next = Key(percentage: percentage, points: points)
        if key == next { return value }
        value = measure(percentage, points)
        key = next
        return value
    }

    static func measureInset(_ percentageText: String, _ pointsText: String) -> CGFloat {
        let percentage = NSAttributedString(string: percentageText, attributes: [.font: percentageFont])
        let points = NSAttributedString(string: pointsText, attributes: [.font: pointsFont])
        let percentageInk = CTLineGetImageBounds(CTLineCreateWithAttributedString(percentage), nil)
        let pointsInk = CTLineGetImageBounds(CTLineCreateWithAttributedString(points), nil)
        return max(0, (OverlayDimensions.quotaWidth - percentage.size().width) / 2
                   + percentageInk.minX - pointsInk.minX)
    }
}

/// Display-only recovery animation. Raw snapshots remain authoritative.
struct RecoveryFill {
    private(set) var actual: Double?
    private var from = 0.0
    private var started = 0.0
    private var ends: Double?
    static func valid(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite ? max(0, min(100, $0)) : nil }
    }
    mutating func receive(_ value: Double?, at now: Double, animate: Bool) {
        let next = Self.valid(value), previous = actual
        let current = frame(at: now).value ?? 0
        guard next != previous else { if !animate { ends = nil }; return }
        actual = next
        guard let next, animate else { ends = nil; return }
        if previous == nil && next > 0 {
            from = 0; started = now; ends = now + 0.8
        } else if let ends, ends > now {
            from = current; started = now // Retarget without extending the original deadline.
        } else { ends = nil }
    }
    mutating func finish() { ends = nil }
    func frame(at now: Double) -> (value: Double?, animating: Bool) {
        guard let actual else { return (nil, false) }
        guard let ends, now < ends, ends > started else { return (actual, false) }
        let t = max(0, min(1, (now - started) / (ends - started)))
        return (from + (actual - from) * (1 - (1 - t) * (1 - t)), true)
    }
    static func text(_ value: Double?, animating: Bool) -> String {
        guard let value else { return "--%" }
        let rounded = Int(animating ? (value + 1e-9).rounded(.down) : value.rounded())
        return "\(min(value < 100 ? 99 : 100, max(0, rounded)))%"
    }
}

final class OverlayModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    var snapshot: UsageSnapshot = .unavailable("Checking Codex…") {
        willSet {
            if OverlaySnapshotPresentation(snapshot) != OverlaySnapshotPresentation(newValue) {
                objectWillChange.send()
            }
        }
        didSet { receivePresentation() }
    }
    private var fill = RecoveryFill()
    private var fillTimer: Timer?
    private var presentationActive = false
    private var displayed: Double?
    private var fillAnimating = false
    var presentedRemaining: Double? { displayed }
    var presentedPercentageText: String { RecoveryFill.text(displayed, animating: fillAnimating) }
    var isAnimatingRecovery: Bool { fillTimer != nil }

    func setPresentationActive(_ active: Bool) {
        presentationActive = active
        if !active { finishPresentation() }
    }
    private func receivePresentation() {
        let now = ProcessInfo.processInfo.systemUptime
        fill.receive(snapshot.remaining, at: now,
                     animate: presentationActive && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        updatePresentation(at: now)
        if fillAnimating && fillTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                guard let self else { return }
                if !self.presentationActive || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    self.finishPresentation(); return
                }
                self.objectWillChange.send()
                self.updatePresentation(at: ProcessInfo.processInfo.systemUptime)
            }
            RunLoop.main.add(timer, forMode: .common)
            fillTimer = timer
        }
    }
    private func updatePresentation(at now: Double) {
        let frame = fill.frame(at: now)
        displayed = frame.value; fillAnimating = frame.animating
        if !frame.animating { fillTimer?.invalidate(); fillTimer = nil }
    }
    private func finishPresentation() {
        if fillTimer != nil { objectWillChange.send() }
        fill.finish(); updatePresentation(at: ProcessInfo.processInfo.systemUptime)
    }
    deinit { fillTimer?.invalidate() }

    var isDarkBackground = true {
        willSet { if newValue != isDarkBackground { objectWillChange.send() } }
    }
    var connectionState: GPTConnectionState = .checking {
        willSet { if newValue != connectionState { objectWillChange.send() } }
    }
    private var downloadRate: Double? = nil
    private var uploadRate: Double? = nil
    private let quotaMetrics = QuotaTextMetricsCache()

    var downloadBytesPerSecond: Double? {
        get { downloadRate }
        set { updateRates(download: newValue, upload: uploadRate) }
    }
    var uploadBytesPerSecond: Double? {
        get { uploadRate }
        set { updateRates(download: downloadRate, upload: newValue) }
    }
    func updateRates(download: Double?, upload: Double?) {
        if OverlayLabels.rate(downloadRate) != OverlayLabels.rate(download)
            || OverlayLabels.rate(uploadRate) != OverlayLabels.rate(upload) {
            objectWillChange.send()
        }
        downloadRate = download
        uploadRate = upload
    }
    var pointsLeadingInset: CGFloat {
        quotaMetrics.inset(percentage: presentedPercentageText, points: OverlayLabels.points(snapshot))
    }
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

/// Presentation-only compact labels. Original account details remain in accessibility/tooltips.
enum OverlayLabels {
    static func rate(_ bytes: Double?) -> String {
        guard let bytes, bytes.isFinite, bytes >= 0 else { return "--" }
        var value = max(0, bytes)
        let units = ["B", "K", "M", "G", "T"]
        var index = 0
        while value >= 999.5 && index < units.count - 1 { value /= 1024; index += 1 }
        if index == units.count - 1 && value > 999 { return "999T+" }
        if index >= 2 && value < 10 {
            return String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "") + units[index]
        }
        return "\(Int(value.rounded()))" + units[index]
    }

    static func points(_ snapshot: UsageSnapshot) -> String {
        let suffix = snapshot.resetDetailSuffix ?? snapshot.detail
        guard let part = suffix.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces), part.contains("points") else { return "-- pts" }
        let token = part.replacingOccurrences(of: "points", with: "").trimmingCharacters(in: .whitespaces)
        let value = token.hasSuffix("k") ? Double(token.dropLast()).map { $0 * 1000 } : Double(token)
        guard let value, value.isFinite else { return "-- pts" }
        for (unit, factor) in [("B", 1_000_000_000.0), ("M", 1_000_000.0), ("k", 1000.0)] where abs(value) >= factor {
            return String(format: "%.1f", value / factor).replacingOccurrences(of: ".0", with: "") + unit + " pts"
        }
        return token + " pts"
    }

    static func reset(_ snapshot: UsageSnapshot) -> String {
        if let range = snapshot.detail.range(of: " left") { return String(snapshot.detail[..<range.upperBound]) }
        guard let reset = snapshot.resetText else { return "--" }
        return reset == "now" ? "Reset pending" : reset + " left"
    }
}

enum OverlayDimensions {
    static let width: CGFloat = 308
    // Center every digit count on one fixed axis; never resize the window.
    static let quotaWidth = ceil(("100%" as NSString).size(withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
    ]).width)
    static let cardCapHeight = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium).capHeight
}

struct UsageEdgeTabView: View {
    @ObservedObject var model: OverlayModel
    var contentWidth: CGFloat = OverlayDimensions.width

    private var remaining: Double {
        max(0, min(100, model.presentedRemaining ?? 0))
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
        return text + "。" + model.snapshot.resetCardDisplay.accessibilityText
    }

    private var throughputAccessibilityText: String {
        "整机下载每秒 \(OverlayLabels.rate(model.downloadBytesPerSecond))，整机上传每秒 \(OverlayLabels.rate(model.uploadBytesPerSecond))"
    }

    /// Compact card/expiry row above throughput; numeric rate columns avoid update jitter.
    fileprivate var statusAccessory: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    ZStack {
                        Image(systemName: "rectangle.on.rectangle")
                            .resizable()
                            .scaledToFit()
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 6.5, weight: .medium))
                            .offset(x: 1.5, y: 1)
                    }
                    .frame(width: 16, height: 12)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center] + OverlayDimensions.cardCapHeight / 2
                    }
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 10, weight: .medium))
                    .accessibilityHidden(true)
                    Text(model.snapshot.resetCardDisplay.countText)
                        .font(.system(size: 10, weight: .medium))
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text(model.snapshot.resetCardDisplay.expiryText)
                    .font(.system(size: 10, weight: .medium))
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 18)
            .overlay(alignment: .bottomLeading) {
                Rectangle()
                    .fill(primaryColor.opacity(0.16))
                    .frame(width: 104, height: 0.5)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.snapshot.resetCardDisplay.accessibilityText)

            HStack(spacing: 6) {
                Text("↓\(OverlayLabels.rate(model.downloadBytesPerSecond))")
                    .frame(width: 43, alignment: .leading)
                Text("↑\(OverlayLabels.rate(model.uploadBytesPerSecond))")
                    .frame(width: 43, alignment: .leading)
                Circle()
                    .fill(model.connectionState.color)
                    .frame(width: 6, height: 6)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(secondaryColor)
            .frame(height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.connectionState.label)。\(throughputAccessibilityText)")
        }
        .monospacedDigit()
        .lineLimit(1)
        .frame(width: 104, height: 36, alignment: .leading)
    }

    fileprivate var content: some View {
        let pointsInset = model.pointsLeadingInset
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                GPTMark()
                    .frame(width: 20, height: 20)
                    .accessibilityLabel("ChatGPT")
                VStack(spacing: 0) {
                    Text(model.presentedPercentageText)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: OverlayDimensions.quotaWidth, height: 24, alignment: .center)
                    Text(OverlayLabels.points(model.snapshot))
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(secondaryColor)
                        .minimumScaleFactor(0.8)
                        .frame(width: OverlayDimensions.quotaWidth - pointsInset, height: 12, alignment: .leading)
                        .padding(.leading, pointsInset)
                }
            }
            .frame(width: 24 + OverlayDimensions.quotaWidth, height: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                Text(OverlayLabels.reset(model.snapshot))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(height: 18, alignment: .leading)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(primaryColor.opacity(0.12))
                        Capsule().fill(progressColor)
                            .frame(width: geometry.size.width * remaining / 100)
                    }
                }
                .frame(height: 4)
                .frame(height: 18)
                .accessibilityLabel("Remaining usage \(model.snapshot.percentageText)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 36)

            statusAccessory
        }
        .foregroundStyle(primaryColor)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: contentWidth, height: 52)
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
                "clientInfo": ["name": "usage-topbar", "title": "Usage Topbar", "version": "0.5.0"],
                "capabilities": ["experimentalApi": true]
            ]])
        } catch {
            fail("Start failed · retrying", restart: true)
        }
    }

    private func disconnectProcess(waitForExit: Bool = false) {
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
            if waitForExit, let child {
                // During application termination the main run loop will stop. Reap our
                // own child here instead of relying on a callback after app exit.
                let deadline = Date().addingTimeInterval(0.5)
                while child.isRunning && Date() < deadline { usleep(10_000) }
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let child, child.isRunning { kill(child.processIdentifier, SIGKILL) }
                }
            }
        }
        buffer.removeAll(keepingCapacity: true)
    }

    func stop(waitForChildExit: Bool = false) {
        isStopped = true
        restartTimer?.invalidate(); restartTimer = nil
        pathMonitor?.cancel(); pathMonitor = nil
        pathIsSatisfied = false
        disconnectProcess(waitForExit: waitForChildExit)
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
        send(["method": "account/rateLimits/read", "id": id, "params": ["excludeResetCreditDetails": false]])
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

    func parseReadResponse(_ result: [String: Any], now: Date = Date()) -> UsageSnapshot? {
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
        guard var snapshot = parseRateLimits(limits, now: now) else { return nil }
        snapshot.resetCards = ResetCards.parse(result["rateLimitResetCredits"])
        return snapshot.refreshed(at: now)
    }

    private func parseRateLimits(_ limits: [String: Any], now: Date) -> UsageSnapshot? {
        let windows = [parseWindow(limits["primary"]), parseWindow(limits["secondary"])].compactMap { $0 }
        // Keep percentage and deadline paired to the same constrained quota window.
        let limiting = windows.min(by: { $0.remaining < $1.remaining })
        guard let remaining = limiting?.remaining ?? creditFallback(limits) else { return nil }
        let points: String
        if let credits = limits["credits"] as? [String: Any], let balance = number(credits["balance"]) {
            points = formatPoints(balance)
        } else {
            points = "points --"
        }
        let otherWindows = windows.filter {
            $0.label != limiting?.label && abs($0.remaining - remaining) >= 1
        }.map { "\($0.label) quota \(Int($0.remaining.rounded()))%" }
        let suffix = (otherWindows + [points]).joined(separator: " · ")
        guard let reset = limiting?.resetsAt else {
            return UsageSnapshot(remaining: remaining, detail: "Reset unknown · " + suffix, resetText: nil)
        }
        return UsageSnapshot(remaining: remaining, detail: "", resetText: nil,
                             resetsAt: reset, resetDetailSuffix: suffix).refreshed(at: now)
    }

    private func parseWindow(_ value: Any?) -> (remaining: Double, label: String, resetsAt: Double?)? {
        guard let window = value as? [String: Any], let used = number(window["usedPercent"]) else { return nil }
        // account/rateLimits/read uses resetsAt (Unix seconds). Tolerate epoch
        // milliseconds explicitly; reject malformed values rather than clamp to years.
        let reset = number(window["resetsAt"]).flatMap { raw -> Double? in
            let seconds = raw >= 1_000_000_000_000 ? raw / 1000 : raw
            guard seconds > 0, seconds < 4_102_444_800 else { return nil }
            return seconds
        }
        return (max(0, min(100, 100 - used)), durationLabel(number(window["windowDurationMins"])), reset)
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
    static func observedRates(previous: [String: NetworkBytes], current: [String: NetworkBytes],
                              elapsed: TimeInterval, maximumGap: TimeInterval) -> (Double, Double)? {
        let shared = Set(previous.keys).intersection(current.keys)
        guard elapsed > 0, elapsed <= maximumGap, !shared.isEmpty,
              shared.allSatisfy({ current[$0]!.received >= previous[$0]!.received && current[$0]!.sent >= previous[$0]!.sent }) else { return nil }
        return rates(previous: previous, current: current, elapsed: elapsed, maximumGap: maximumGap)
    }

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
    var onRates: ((_ downloadBytesPerSecond: Double?, _ uploadBytesPerSecond: Double?) -> Void)?
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
        onRates?(nil, nil)
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
        guard let current, let previous = previousTotals else { onRates?(nil, nil); return }
        let rates = NetworkRateCalculator.observedRates(previous: previous, current: current,
            elapsed: now - previousTime, maximumGap: activeSampleInterval * 3)
        onRates?(rates?.0, rates?.1)
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

// OpenAI / ChatGPT mark: https://cdn.oaistatic.com/assets/favicon-l4nq08hd.svg
// Trademark belongs to OpenAI. Used only as the service indicator.
struct GPTMark: Shape {
    private static let outline: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 101.228, y: 164.247))
        p.addCurve(to: CGPoint(x: 87.1201, y: 161.426), control1: CGPoint(x: 96.2776, y: 164.247), control2: CGPoint(x: 91.5751, y: 163.307))
        p.addCurve(to: CGPoint(x: 75.2401, y: 153.555), control1: CGPoint(x: 82.6651, y: 159.545), control2: CGPoint(x: 78.7051, y: 156.921))
        p.addCurve(to: CGPoint(x: 63.5086, y: 155.486), control1: CGPoint(x: 71.4781, y: 154.842), control2: CGPoint(x: 67.5676, y: 155.486))
        p.addCurve(to: CGPoint(x: 45.0946, y: 150.585), control1: CGPoint(x: 56.8756, y: 155.486), control2: CGPoint(x: 50.7376, y: 153.852))
        p.addCurve(to: CGPoint(x: 31.4326, y: 137.22), control1: CGPoint(x: 39.4516, y: 147.318), control2: CGPoint(x: 34.8976, y: 142.863))
        p.addCurve(to: CGPoint(x: 26.3836, y: 118.361), control1: CGPoint(x: 28.0666, y: 131.577), control2: CGPoint(x: 26.3836, y: 125.291))
        p.addCurve(to: CGPoint(x: 27.5716, y: 109.005), control1: CGPoint(x: 26.3836, y: 115.49), control2: CGPoint(x: 26.7796, y: 112.371))
        p.addCurve(to: CGPoint(x: 18.3646, y: 96.3828), control1: CGPoint(x: 23.6116, y: 105.342), control2: CGPoint(x: 20.5426, y: 101.135))
        p.addCurve(to: CGPoint(x: 15.0976, y: 81.2358), control1: CGPoint(x: 16.1866, y: 91.5318), control2: CGPoint(x: 15.0976, y: 86.4828))
        p.addCurve(to: CGPoint(x: 18.5131, y: 65.7918), control1: CGPoint(x: 15.0976, y: 75.8898), control2: CGPoint(x: 16.2361, y: 70.7418))
        p.addCurve(to: CGPoint(x: 28.0171, y: 53.0208), control1: CGPoint(x: 20.7901, y: 60.8418), control2: CGPoint(x: 23.9581, y: 56.5848))
        p.addCurve(to: CGPoint(x: 42.4216, y: 45.4473), control1: CGPoint(x: 32.1751, y: 49.3578), control2: CGPoint(x: 36.9766, y: 46.8333))
        p.addCurve(to: CGPoint(x: 49.2526, y: 30.3003), control1: CGPoint(x: 43.5106, y: 39.8043), control2: CGPoint(x: 45.7876, y: 34.7553))
        p.addCurve(to: CGPoint(x: 62.3206, y: 19.6083), control1: CGPoint(x: 52.8166, y: 25.7463), control2: CGPoint(x: 57.1726, y: 22.1823))
        p.addCurve(to: CGPoint(x: 78.8041, y: 15.7473), control1: CGPoint(x: 67.4686, y: 17.0343), control2: CGPoint(x: 72.9631, y: 15.7473))
        p.addCurve(to: CGPoint(x: 92.9116, y: 18.5688), control1: CGPoint(x: 83.7541, y: 15.7473), control2: CGPoint(x: 88.4566, y: 16.6878))
        p.addCurve(to: CGPoint(x: 104.792, y: 26.4393), control1: CGPoint(x: 97.3666, y: 20.4498), control2: CGPoint(x: 101.327, y: 23.0733))
        p.addCurve(to: CGPoint(x: 116.523, y: 24.5088), control1: CGPoint(x: 108.554, y: 25.1523), control2: CGPoint(x: 112.464, y: 24.5088))
        p.addCurve(to: CGPoint(x: 134.937, y: 29.4093), control1: CGPoint(x: 123.156, y: 24.5088), control2: CGPoint(x: 129.294, y: 26.1423))
        p.addCurve(to: CGPoint(x: 148.451, y: 42.7743), control1: CGPoint(x: 140.58, y: 32.6763), control2: CGPoint(x: 145.085, y: 37.1313))
        p.addCurve(to: CGPoint(x: 153.648, y: 61.6338), control1: CGPoint(x: 151.916, y: 48.4173), control2: CGPoint(x: 153.648, y: 54.7038))
        p.addCurve(to: CGPoint(x: 152.46, y: 70.9893), control1: CGPoint(x: 153.648, y: 64.5048), control2: CGPoint(x: 153.252, y: 67.6233))
        p.addCurve(to: CGPoint(x: 161.667, y: 83.7603), control1: CGPoint(x: 156.42, y: 74.6523), control2: CGPoint(x: 159.489, y: 78.9093))
        p.addCurve(to: CGPoint(x: 164.934, y: 98.7588), control1: CGPoint(x: 163.845, y: 88.5123), control2: CGPoint(x: 164.934, y: 93.5118))
        p.addCurve(to: CGPoint(x: 161.519, y: 114.203), control1: CGPoint(x: 164.934, y: 104.105), control2: CGPoint(x: 163.796, y: 109.253))
        p.addCurve(to: CGPoint(x: 151.866, y: 127.122), control1: CGPoint(x: 159.242, y: 119.153), control2: CGPoint(x: 156.024, y: 123.459))
        p.addCurve(to: CGPoint(x: 137.61, y: 134.547), control1: CGPoint(x: 147.807, y: 130.686), control2: CGPoint(x: 143.055, y: 133.161))
        p.addCurve(to: CGPoint(x: 130.631, y: 149.694), control1: CGPoint(x: 136.521, y: 140.19), control2: CGPoint(x: 134.195, y: 145.239))
        p.addCurve(to: CGPoint(x: 117.711, y: 160.386), control1: CGPoint(x: 127.166, y: 154.248), control2: CGPoint(x: 122.859, y: 157.812))
        p.addCurve(to: CGPoint(x: 101.228, y: 164.247), control1: CGPoint(x: 112.563, y: 162.96), control2: CGPoint(x: 107.069, y: 164.247))
        p.closeSubpath()
        p.move(to: CGPoint(x: 64.5481, y: 145.685))
        p.addCurve(to: CGPoint(x: 77.4676, y: 142.566), control1: CGPoint(x: 69.4981, y: 145.685), control2: CGPoint(x: 73.8046, y: 144.645))
        p.addLine(to: CGPoint(x: 105.386, y: 126.528))
        p.addCurve(to: CGPoint(x: 106.871, y: 123.707), control1: CGPoint(x: 106.376, y: 125.835), control2: CGPoint(x: 106.871, y: 124.895))
        p.addLine(to: CGPoint(x: 106.871, y: 110.936))
        p.addLine(to: CGPoint(x: 70.9336, y: 131.577))
        p.addCurve(to: CGPoint(x: 64.3996, y: 131.577), control1: CGPoint(x: 68.7556, y: 132.864), control2: CGPoint(x: 66.5776, y: 132.864))
        p.addLine(to: CGPoint(x: 36.3331, y: 115.391))
        p.addCurve(to: CGPoint(x: 36.1846, y: 116.43), control1: CGPoint(x: 36.3331, y: 115.688), control2: CGPoint(x: 36.2836, y: 116.034))
        p.addCurve(to: CGPoint(x: 36.1846, y: 118.212), control1: CGPoint(x: 36.1846, y: 116.826), control2: CGPoint(x: 36.1846, y: 117.42))
        p.addCurve(to: CGPoint(x: 39.7486, y: 132.171), control1: CGPoint(x: 36.1846, y: 123.261), control2: CGPoint(x: 37.3726, y: 127.914))
        p.addCurve(to: CGPoint(x: 49.9951, y: 141.972), control1: CGPoint(x: 42.2236, y: 136.329), control2: CGPoint(x: 45.6391, y: 139.596))
        p.addCurve(to: CGPoint(x: 64.5481, y: 145.685), control1: CGPoint(x: 54.3511, y: 144.447), control2: CGPoint(x: 59.2021, y: 145.685))
        p.closeSubpath()
        p.move(to: CGPoint(x: 66.0331, y: 121.479))
        p.addCurve(to: CGPoint(x: 67.6666, y: 121.925), control1: CGPoint(x: 66.6271, y: 121.776), control2: CGPoint(x: 67.1716, y: 121.925))
        p.addCurve(to: CGPoint(x: 69.1516, y: 121.479), control1: CGPoint(x: 68.1616, y: 121.925), control2: CGPoint(x: 68.6566, y: 121.776))
        p.addLine(to: CGPoint(x: 80.2891, y: 115.094))
        p.addLine(to: CGPoint(x: 44.5006, y: 94.3038))
        p.addCurve(to: CGPoint(x: 41.2336, y: 88.5123), control1: CGPoint(x: 42.3226, y: 93.0168), control2: CGPoint(x: 41.2336, y: 91.0863))
        p.addLine(to: CGPoint(x: 41.2336, y: 56.2878))
        p.addCurve(to: CGPoint(x: 29.3536, y: 66.3858), control1: CGPoint(x: 36.2836, y: 58.4658), control2: CGPoint(x: 32.3236, y: 61.8318))
        p.addCurve(to: CGPoint(x: 24.8986, y: 81.2358), control1: CGPoint(x: 26.3836, y: 70.8408), control2: CGPoint(x: 24.8986, y: 75.7908))
        p.addCurve(to: CGPoint(x: 28.6111, y: 95.1948), control1: CGPoint(x: 24.8986, y: 86.0868), control2: CGPoint(x: 26.1361, y: 90.7398))
        p.addCurve(to: CGPoint(x: 38.2636, y: 105.293), control1: CGPoint(x: 31.0861, y: 99.6498), control2: CGPoint(x: 34.3036, y: 103.016))
        p.addLine(to: CGPoint(x: 66.0331, y: 121.479))
        p.closeSubpath()
        p.move(to: CGPoint(x: 101.228, y: 154.446))
        p.addCurve(to: CGPoint(x: 115.484, y: 150.882), control1: CGPoint(x: 106.475, y: 154.446), control2: CGPoint(x: 111.227, y: 153.258))
        p.addCurve(to: CGPoint(x: 125.582, y: 141.081), control1: CGPoint(x: 119.741, y: 148.506), control2: CGPoint(x: 123.107, y: 145.239))
        p.addCurve(to: CGPoint(x: 129.294, y: 127.122), control1: CGPoint(x: 128.057, y: 136.923), control2: CGPoint(x: 129.294, y: 132.27))
        p.addLine(to: CGPoint(x: 129.294, y: 95.0463))
        p.addCurve(to: CGPoint(x: 127.809, y: 92.3733), control1: CGPoint(x: 129.294, y: 93.8583), control2: CGPoint(x: 128.799, y: 92.9673))
        p.addLine(to: CGPoint(x: 116.523, y: 85.8393))
        p.addLine(to: CGPoint(x: 116.523, y: 127.271))
        p.addCurve(to: CGPoint(x: 113.256, y: 133.062), control1: CGPoint(x: 116.523, y: 129.845), control2: CGPoint(x: 115.434, y: 131.775))
        p.addLine(to: CGPoint(x: 85.1896, y: 149.249))
        p.addCurve(to: CGPoint(x: 101.228, y: 154.446), control1: CGPoint(x: 90.0406, y: 152.714), control2: CGPoint(x: 95.3866, y: 154.446))
        p.closeSubpath()
        p.move(to: CGPoint(x: 106.871, y: 100.095))
        p.addLine(to: CGPoint(x: 106.871, y: 79.8993))
        p.addLine(to: CGPoint(x: 90.09, y: 70.3953))
        p.addLine(to: CGPoint(x: 73.1611, y: 79.8993))
        p.addLine(to: CGPoint(x: 73.1611, y: 100.095))
        p.addLine(to: CGPoint(x: 90.09, y: 109.599))
        p.addLine(to: CGPoint(x: 106.871, y: 100.095))
        p.closeSubpath()
        p.move(to: CGPoint(x: 63.5086, y: 52.7238))
        p.addCurve(to: CGPoint(x: 66.7756, y: 46.9323), control1: CGPoint(x: 63.5086, y: 50.1498), control2: CGPoint(x: 64.5976, y: 48.2193))
        p.addLine(to: CGPoint(x: 94.8421, y: 30.7458))
        p.addCurve(to: CGPoint(x: 78.8041, y: 25.5483), control1: CGPoint(x: 89.9911, y: 27.2808), control2: CGPoint(x: 84.6451, y: 25.5483))
        p.addCurve(to: CGPoint(x: 64.5481, y: 29.1123), control1: CGPoint(x: 73.5571, y: 25.5483), control2: CGPoint(x: 68.8051, y: 26.7363))
        p.addCurve(to: CGPoint(x: 54.4501, y: 38.9133), control1: CGPoint(x: 60.2911, y: 31.4883), control2: CGPoint(x: 56.9251, y: 34.7553))
        p.addCurve(to: CGPoint(x: 50.8861, y: 52.8723), control1: CGPoint(x: 52.0741, y: 43.0713), control2: CGPoint(x: 50.8861, y: 47.7243))
        p.addLine(to: CGPoint(x: 50.8861, y: 84.7998))
        p.addCurve(to: CGPoint(x: 52.3711, y: 87.6213), control1: CGPoint(x: 50.8861, y: 85.9878), control2: CGPoint(x: 51.3811, y: 86.9283))
        p.addLine(to: CGPoint(x: 63.5086, y: 94.1553))
        p.addLine(to: CGPoint(x: 63.5086, y: 52.7238))
        p.closeSubpath()
        p.move(to: CGPoint(x: 138.947, y: 123.707))
        p.addCurve(to: CGPoint(x: 150.678, y: 113.609), control1: CGPoint(x: 143.897, y: 121.529), control2: CGPoint(x: 147.807, y: 118.163))
        p.addCurve(to: CGPoint(x: 155.133, y: 98.7588), control1: CGPoint(x: 153.648, y: 109.055), control2: CGPoint(x: 155.133, y: 104.105))
        p.addCurve(to: CGPoint(x: 151.421, y: 84.7998), control1: CGPoint(x: 155.133, y: 93.9078), control2: CGPoint(x: 153.896, y: 89.2548))
        p.addCurve(to: CGPoint(x: 141.768, y: 74.7018), control1: CGPoint(x: 148.946, y: 80.3448), control2: CGPoint(x: 145.728, y: 76.9788))
        p.addLine(to: CGPoint(x: 113.999, y: 58.6638))
        p.addCurve(to: CGPoint(x: 112.365, y: 58.2183), control1: CGPoint(x: 113.405, y: 58.2678), control2: CGPoint(x: 112.86, y: 58.1193))
        p.addCurve(to: CGPoint(x: 110.88, y: 58.6638), control1: CGPoint(x: 111.87, y: 58.2183), control2: CGPoint(x: 111.375, y: 58.3668))
        p.addLine(to: CGPoint(x: 99.7426, y: 64.9008))
        p.addLine(to: CGPoint(x: 135.68, y: 85.8393))
        p.addCurve(to: CGPoint(x: 138.056, y: 88.2153), control1: CGPoint(x: 136.769, y: 86.4333), control2: CGPoint(x: 137.561, y: 87.2253))
        p.addCurve(to: CGPoint(x: 138.947, y: 91.4823), control1: CGPoint(x: 138.65, y: 89.1063), control2: CGPoint(x: 138.947, y: 90.1953))
        p.addLine(to: CGPoint(x: 138.947, y: 123.707))
        p.closeSubpath()
        p.move(to: CGPoint(x: 109.098, y: 48.2688))
        p.addCurve(to: CGPoint(x: 115.632, y: 48.2688), control1: CGPoint(x: 111.276, y: 46.8828), control2: CGPoint(x: 113.454, y: 46.8828))
        p.addLine(to: CGPoint(x: 143.847, y: 64.7523))
        p.addCurve(to: CGPoint(x: 143.847, y: 62.0793), control1: CGPoint(x: 143.847, y: 64.0593), control2: CGPoint(x: 143.847, y: 63.1683))
        p.addCurve(to: CGPoint(x: 140.283, y: 48.5658), control1: CGPoint(x: 143.847, y: 57.3273), control2: CGPoint(x: 142.659, y: 52.8228))
        p.addCurve(to: CGPoint(x: 130.334, y: 38.1708), control1: CGPoint(x: 138.006, y: 44.2098), control2: CGPoint(x: 134.69, y: 40.7448))
        p.addCurve(to: CGPoint(x: 115.484, y: 34.3098), control1: CGPoint(x: 126.077, y: 35.5968), control2: CGPoint(x: 121.127, y: 34.3098))
        p.addCurve(to: CGPoint(x: 102.564, y: 37.4283), control1: CGPoint(x: 110.534, y: 34.3098), control2: CGPoint(x: 106.227, y: 35.3493))
        p.addLine(to: CGPoint(x: 74.6461, y: 53.4663))
        p.addCurve(to: CGPoint(x: 73.1611, y: 56.2878), control1: CGPoint(x: 73.6561, y: 54.1593), control2: CGPoint(x: 73.1611, y: 55.0998))
        p.addLine(to: CGPoint(x: 73.1611, y: 69.0588))
        p.addLine(to: CGPoint(x: 109.098, y: 48.2688))
        p.closeSubpath()
        return p
    }()

    func path(in rect: CGRect) -> Path {
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / 180, y: rect.height / 180)
        return Path(Self.outline.copy(using: &transform)!)
    }

    static let statusImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.translateBy(x: 0, y: rect.height)
            context.scaleBy(x: rect.width / 180, y: -rect.height / 180)
            context.addPath(outline)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ChatGPT"
        return image
    }()
}

/// Menu-bar-only Codex mark. Exact path from assets/codex-mark.svg.
/// Keep independent of GPTMark, which is used by the floating overlay.
enum CodexMark {
    static let outline: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 20, y: 12))
        path.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: 20, y: 7.58172), control2: CGPoint(x: 16.4183, y: 4))
        path.addCurve(to: CGPoint(x: 4, y: 12), control1: CGPoint(x: 7.58172, y: 4), control2: CGPoint(x: 4, y: 7.58172))
        path.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 4, y: 16.4183), control2: CGPoint(x: 7.58172, y: 20))
        path.addCurve(to: CGPoint(x: 20, y: 12), control1: CGPoint(x: 16.4183, y: 20), control2: CGPoint(x: 20, y: 16.4183))
        path.closeSubpath()
        path.move(to: CGPoint(x: 16, y: 13.5))
        path.addCurve(to: CGPoint(x: 17, y: 14.5), control1: CGPoint(x: 16.5523, y: 13.5), control2: CGPoint(x: 17, y: 13.9477))
        path.addCurve(to: CGPoint(x: 16, y: 15.5), control1: CGPoint(x: 17, y: 15.0523), control2: CGPoint(x: 16.5523, y: 15.5))
        path.addLine(to: CGPoint(x: 13, y: 15.5))
        path.addCurve(to: CGPoint(x: 12, y: 14.5), control1: CGPoint(x: 12.4477, y: 15.5), control2: CGPoint(x: 12, y: 15.0523))
        path.addCurve(to: CGPoint(x: 13, y: 13.5), control1: CGPoint(x: 12, y: 13.9477), control2: CGPoint(x: 12.4477, y: 13.5))
        path.addLine(to: CGPoint(x: 16, y: 13.5))
        path.closeSubpath()
        path.move(to: CGPoint(x: 7.98535, y: 8.64258))
        path.addCurve(to: CGPoint(x: 9.30078, y: 8.90039), control1: CGPoint(x: 8.42937, y: 8.37617), control2: CGPoint(x: 8.99745, y: 8.49427))
        path.addLine(to: CGPoint(x: 9.35742, y: 8.98535))
        path.addLine(to: CGPoint(x: 10.8574, y: 11.4854))
        path.addLine(to: CGPoint(x: 10.9199, y: 11.6074))
        path.addCurve(to: CGPoint(x: 10.9199, y: 12.3926), control1: CGPoint(x: 11.0269, y: 11.858), control2: CGPoint(x: 11.0269, y: 12.142))
        path.addLine(to: CGPoint(x: 10.8574, y: 12.5146))
        path.addLine(to: CGPoint(x: 9.35742, y: 15.0146))
        path.addCurve(to: CGPoint(x: 7.98535, y: 15.3574), control1: CGPoint(x: 9.07324, y: 15.4881), control2: CGPoint(x: 8.45888, y: 15.6415))
        path.addCurve(to: CGPoint(x: 7.64258, y: 13.9854), control1: CGPoint(x: 7.51188, y: 15.0732), control2: CGPoint(x: 7.35846, y: 14.4589))
        path.addLine(to: CGPoint(x: 8.83301, y: 12))
        path.addLine(to: CGPoint(x: 7.64258, y: 10.0146))
        path.addLine(to: CGPoint(x: 7.59473, y: 9.92383))
        path.addCurve(to: CGPoint(x: 7.98535, y: 8.64258), control1: CGPoint(x: 7.37931, y: 9.46516), control2: CGPoint(x: 7.54152, y: 8.90898))
        path.closeSubpath()
        path.move(to: CGPoint(x: 22, y: 12))
        path.addCurve(to: CGPoint(x: 12, y: 22), control1: CGPoint(x: 22, y: 17.5228), control2: CGPoint(x: 17.5228, y: 22))
        path.addCurve(to: CGPoint(x: 2, y: 12), control1: CGPoint(x: 6.47715, y: 22), control2: CGPoint(x: 2, y: 17.5228))
        path.addCurve(to: CGPoint(x: 12, y: 2), control1: CGPoint(x: 2, y: 6.47715), control2: CGPoint(x: 6.47715, y: 2))
        path.addCurve(to: CGPoint(x: 22, y: 12), control1: CGPoint(x: 17.5228, y: 2), control2: CGPoint(x: 22, y: 6.47715))
        path.closeSubpath()
        return path
    }()

    static let statusImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: rect.width / 24, y: -rect.height / 24)
            context.addPath(outline)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Codex"
        return image
    }()
}

/// Screen coordinates are AppKit points, independent of Retina backing pixels.
enum OverlayPlacement {
    struct Display {
        let frame: CGRect
        let visibleFrame: CGRect
        let scale: CGFloat
    }

    static func appKitBounds(_ bounds: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: primaryTop - bounds.maxY,
               width: bounds.width, height: bounds.height)
    }

    static func frame(window: CGRect, displays: [Display]) -> CGRect? {
        // Choose once from full display bounds; use that same display's safe
        // frame and backing scale. Menu bar/Dock areas must not change ownership.
        guard let display = displays.max(by: {
            intersectionArea($0.frame, window) < intersectionArea($1.frame, window)
        }), intersectionArea(display.frame, window) > 0 else { return nil }
        let screen = display.visibleFrame
        guard !screen.isNull, screen.width >= OverlayDimensions.width, screen.height >= 74 else { return nil }
        let factor = display.scale.isFinite ? max(1, display.scale) : 1
        let minX = ceil(screen.minX * factor) / factor
        let maxX = floor((screen.maxX - OverlayDimensions.width) * factor) / factor
        guard minX <= maxX else { return nil }
        let x = min(max((window.minX * factor).rounded() / factor, minX), maxX)
        let y = ((window.maxY - 22) * factor).rounded() / factor
        let frame = CGRect(x: x, y: y, width: OverlayDimensions.width, height: 74)
        // Test the rounded result, including the notch/menu bar/Dock boundary.
        guard screen.contains(frame) else { return nil }
        return frame
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}

enum OverlayTrackingPolicy {
    static let activeInterval: TimeInterval = 0.2
    static let idleInterval: TimeInterval = 1

    static func interval(targetActive: Bool, userHidden: Bool, sleeping: Bool) -> TimeInterval? {
        if sleeping { return nil }
        return targetActive && !userHidden ? activeInterval : idleInterval
    }
}

final class LoginItemController {
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    init(status: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }) {
        readStatus = status; self.register = register; self.unregister = unregister
    }
    var status: SMAppService.Status { readStatus() }
    func toggle() throws {
        switch status {
        case .enabled, .requiresApproval: try unregister()
        case .notRegistered, .notFound: try register()
        @unknown default: throw NSError(domain: "UsageTopbar.LoginItem", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "无法读取登录项状态。"])
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private struct TrackedWindow {
        let bounds: CGRect
        let id: CGWindowID
        let orderIndex: Int
        let overlayOrderIndex: Int?
    }

    private let overlayWidth = OverlayDimensions.width
    private let overlayHeight: CGFloat = 74
    private var panel: NSPanel!
    private let overlayModel = OverlayModel()
    private var statusItem: NSStatusItem!
    private var rateClient: RateLimitClient?
    private var networkUsageMonitor: SystemNetworkUsageMonitor?
    private var positionTimer: Timer?
    private var positionTrackingEnabled = false
    private var countdownTimer: Timer?
    private var mockTimer: Timer?
    private var mockRemaining = 68.0
    private var lastContrastSample = Date.distantPast
    private var currentDarkBackground: Bool?
    private var contrastSamplePending = false
    private let preferences = OverlayPreferences()
    private var userHidden = false
    private var sleeping = false
    private let loginItemController = LoginItemController()
    private var loginItemMenu: NSMenuItem?
    @MainActor private lazy var appUpdater = AppUpdateController.production()
    private var didStart = false
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didStart else { return }
        didStart = true
        userHidden = preferences.userHidden
        configureApplicationIcon()
        configureStatusItem()
        configurePanel()
        if CommandLine.arguments.contains("--mock") { startMock() } else { startLive() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        overlayModel.setPresentationActive(false)
        rateClient?.stop(waitForChildExit: true)
        networkUsageMonitor?.stop()
        stopPositionTracking()
        mockTimer?.invalidate()
        countdownTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
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
        statusItem.button?.title = " --%"
        statusItem.button?.image = CodexMark.statusImage
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusItem.button?.toolTip = "Usage Topbar — Codex remaining usage"
        let menu = NSMenu()
        menu.addItem(withTitle: "立即刷新", action: #selector(refreshNow), keyEquivalent: "r")
        menu.addItem(withTitle: "显示/隐藏浮层", action: #selector(togglePanel), keyEquivalent: "h")
        menu.addItem(.separator())
        loginItemMenu = menu.addItem(withTitle: "开机自启", action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.delegate = self
        updateLoginItemMenu()
        menu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(withTitle: "退出 Usage Topbar", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) { updateLoginItemMenu() }

    private func updateLoginItemMenu() {
        let status = loginItemController.status
        loginItemMenu?.state = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
        loginItemMenu?.title = status == .requiresApproval ? "开机自启（待系统批准）" : "开机自启"
        loginItemMenu?.toolTip = status == .requiresApproval
            ? "可在系统设置的登录项中批准；再次点击可取消注册。" : "登录 Mac 时打开 Usage Topbar"
    }

    @objc private func toggleLoginItem() {
        do { try loginItemController.toggle() }
        catch {
            let alert = NSAlert()
            alert.messageText = "未能更改开机自启"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
        updateLoginItemMenu()
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
                if self?.statusItem.button?.title != " --%" { self?.statusItem.button?.title = " --%" }
                self?.overlayModel.snapshot = .unavailable(status)
            }
        }
        client.onConnectionState = { [weak self] state in
            Task { @MainActor in
                self?.overlayModel.connectionState = state
            }
        }
        rateClient = client
        // A local text tick only; authenticated usage polling stays at 30 seconds.
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.apply(self.overlayModel.snapshot.refreshed())
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        client.start()
        let usageMonitor = SystemNetworkUsageMonitor()
        usageMonitor.onRates = { [weak self] download, upload in
            Task { @MainActor in
                self?.overlayModel.updateRates(download: download, upload: upload)
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
        // Synthetic demos follow system appearance without screen sampling.
        overlayModel.isDarkBackground = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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
            self.apply(UsageSnapshot(remaining: self.mockRemaining, detail: "", resetText: nil,
                                     resetsAt: self.overlayModel.snapshot.resetsAt,
                                     resetDetailSuffix: "120 points").refreshed())
        }
    }

    private func startPositionTracking() {
        positionTrackingEnabled = true
        synchronizePanelVisibility()
    }

    private func stopPositionTracking() {
        positionTrackingEnabled = false
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func updatePositionTrackingCadence(for application: NSRunningApplication?) {
        guard positionTrackingEnabled else { return }
        let interval = OverlayTrackingPolicy.interval(targetActive: isCodexApplication(application),
                                                     userHidden: userHidden, sleeping: sleeping)
        if let interval, let timer = positionTimer, timer.isValid, timer.timeInterval == interval { return }
        positionTimer?.invalidate()
        positionTimer = nil
        guard let interval else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.synchronizePanelVisibility()
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        positionTimer = timer
    }

    private func synchronizePanelVisibility() {
        updatePanelVisibility(for: NSWorkspace.shared.frontmostApplication)
    }

    private func startActivationTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screensChanged(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
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
        overlayModel.setPresentationActive(false)
        panel.orderOut(nil)
        stopPositionTracking()
        rateClient?.stop()
        networkUsageMonitor?.stop()
        overlayModel.snapshot = .unavailable("Sleeping · data unavailable")
        overlayModel.connectionState = .checking
        statusItem.button?.title = " --%"
    }

    @objc private func didWake(_ notification: Notification) {
        apply(overlayModel.snapshot.refreshed())
        sleeping = false
        currentDarkBackground = nil
        lastContrastSample = .distantPast
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
        guard !isTerminating else { return }
        updatePositionTrackingCadence(for: application)
        guard let application,
              !userHidden, !sleeping,
              isCodexApplication(application) else {
            hidePanelIfNeeded()
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
        if overlayModel.snapshot != snapshot { overlayModel.snapshot = snapshot }
        let title = " \(snapshot.percentageText)"
        let tooltip = "Usage Topbar — Codex remaining usage\n" + snapshot.detail + "\n" + snapshot.resetCardDisplay.accessibilityText
        if statusItem.button?.title != title { statusItem.button?.title = title }
        if statusItem.button?.toolTip != tooltip { statusItem.button?.toolTip = tooltip }
    }

    private func positionPanel(for window: TrackedWindow) -> Bool {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return false }
        let converted = OverlayPlacement.appKitBounds(window.bounds, primaryTop: primary.frame.maxY)
        let displays = screens.map { screen in
            let safeTop = screen.frame.maxY - screen.safeAreaInsets.top
            let safeFrame = screen.visibleFrame.intersection(CGRect(
                x: screen.frame.minX, y: screen.frame.minY,
                width: screen.frame.width, height: safeTop - screen.frame.minY))
            return OverlayPlacement.Display(frame: screen.frame, visibleFrame: safeFrame,
                                            scale: screen.backingScaleFactor)
        }
        guard let frame = OverlayPlacement.frame(window: converted, displays: displays) else { return false }
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if panel.isVisible { updateContrast(window: window, panelX: frame.minX) }
        return true
    }

    private func hidePanelIfNeeded() {
        overlayModel.setPresentationActive(false)
        if panel.isVisible { panel.orderOut(nil) }
    }

    private func showPanelBehindCodex(for application: NSRunningApplication) {
        guard let window = chatGPTWindow(for: application) else {
            hidePanelIfNeeded()
            return
        }
        guard positionPanel(for: window) else { hidePanelIfNeeded(); return }
        let overlayIsBehindCodex = window.overlayOrderIndex.map { $0 > window.orderIndex } ?? false
        if !panel.isVisible || !overlayIsBehindCodex {
            panel.order(.below, relativeTo: Int(window.id))
        }
        overlayModel.setPresentationActive(panel.isVisible)
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
        guard !isTerminating, !contrastSamplePending,
              Date().timeIntervalSince(lastContrastSample) >= 3 else { return }
        lastContrastSample = Date()

        let fallback = fallbackDarkAppearance()
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else {
            applyContrast(isDarkBackground: fallback)
            return
        }

        contrastSamplePending = true
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, _ in
            guard let self, !self.isTerminating,
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
        guard !isTerminating else { return }
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

    @MainActor @objc private func checkForUpdates() { appUpdater.checkForUpdates() }
    @objc private func refreshNow() { rateClient?.refresh() }
    @objc private func togglePanel() {
        // Keep manual intent separate from automatic hiding caused by window geometry.
        userHidden.toggle()
        if !CommandLine.arguments.contains("--mock") { preferences.userHidden = userHidden }
        synchronizePanelVisibility()
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
    renderer.proposedSize = ProposedViewSize(width: OverlayDimensions.width, height: 74)
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

// Read-only local verification; never changes registration or starts monitoring.
if CommandLine.arguments.contains("--login-item-status") {
    switch SMAppService.mainApp.status {
    case .notRegistered: print("notRegistered")
    case .enabled: print("enabled")
    case .requiresApproval: print("requiresApproval")
    case .notFound: print("notFound")
    @unknown default: print("unknown")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
