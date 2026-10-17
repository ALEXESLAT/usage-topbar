import Foundation
import CryptoKit

enum AppVariant {
    #if USAGE_TOPBAR_TESTING
    static let isTesting = true
    static let name = "Usage Topbar 测试版"
    static let bundleID = "local.alex.usage-topbar.testing"
    static let storageFolder = "UsageTopbar Testing"
    static let statusPrefix = "T"
    #else
    static let isTesting = false
    static let name = "Usage Topbar"
    static let bundleID = "local.alex.usage-topbar"
    static let storageFolder = "UsageTopbar"
    static let statusPrefix = ""
    #endif
}

struct HistoryCard: Codable, Equatable {
    let id: String
    let status: String
    let expiresAt: Double?
}
struct HistoryReading: Codable, Equatable {
    let account: String // One-way digest, never an email, token or raw account ID.
    let series: String
    let time: Double
    let remaining: Double
    let resetsAt: Double?
    let duration: Double
    let cards: [HistoryCard]?
    let availableCards: Int?

    static func parse(_ result: [String: Any], at date: Date) -> [HistoryReading] {
        guard let id = result["accountId"] as? String, !id.isEmpty else { return [] }
        let account = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        let buckets = result["rateLimitsByLimitId"] as? [String: Any]
        guard let bucket = (buckets?["codex"] as? [String: Any]) ?? (result["rateLimits"] as? [String: Any]),
              bucket["limitId"] == nil || bucket["limitId"] is NSNull || bucket["limitId"] as? String == "codex" else { return [] }
        let summary = result["rateLimitResetCredits"] as? [String: Any]
        let count = number(summary?["availableCount"]).flatMap { $0 >= 0 && $0 <= 1_000_000 && $0.rounded() == $0 ? Int($0) : nil }
        var cards: [HistoryCard]?
        if let rows = summary?["credits"] as? [[String: Any]] {
            let parsed = rows.compactMap { row -> HistoryCard? in
                guard let id = row["id"] as? String, !id.isEmpty,
                      row["resetType"] as? String == "codexRateLimits",
                      let status = row["status"] as? String,
                      ["available", "redeeming", "redeemed"].contains(status),
                      row["expiresAt"] is NSNull || number(row["expiresAt"]) != nil else { return nil }
                return HistoryCard(id: SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined(),
                                   status: status, expiresAt: number(row["expiresAt"]))
            }
            if parsed.count == rows.count && Set(parsed.map(\.id)).count == parsed.count { cards = parsed }
        }
        return ["primary", "secondary"].compactMap { key in
            guard let window = bucket[key] as? [String: Any], let used = number(window["usedPercent"]),
                  (0...100).contains(used), let minutes = number(window["windowDurationMins"]),
                  minutes > 0, minutes <= 525600 else { return nil }
            let rawReset = number(window["resetsAt"])
            if let rawReset {
                let seconds = rawReset >= 1e12 ? rawReset / 1000 : rawReset
                guard seconds > date.timeIntervalSince1970, seconds < 4_102_444_800 else { return nil }
            }
            let reset = rawReset.flatMap { value -> Double? in
                let seconds = value >= 1e12 ? value / 1000 : value
                return seconds > date.timeIntervalSince1970 && seconds < 4_102_444_800 ? seconds : nil
            }
            // Different slots/durations never share a line or reset comparison.
            return HistoryReading(account: account, series: "codex/\(key)/\(minutes)", time: date.timeIntervalSince1970,
                                  remaining: 100 - used, resetsAt: reset, duration: minutes * 60,
                                  cards: cards, availableCards: count)
        }
    }
    private static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
}

enum HistoryResetKind: String, Codable { case cycle, card, special, unknown }
struct HistoryReset: Codable, Equatable {
    let kind: HistoryResetKind
    let lowerBound: Double
    let upperBound: Double
    let exactTime: Double?
    let inferred: Bool
    let source: String
}
struct HistoryPoint: Codable, Equatable {
    let reading: HistoryReading
    var gapBefore: Bool
    let event: HistoryReset?
    var gapReason: String? = nil
}

enum HistoryResetClassifier {
    static func classify(previous a: HistoryReading, current b: HistoryReading) -> HistoryReset? {
        guard a.account == b.account, a.series == b.series, b.time > a.time,
              b.remaining > a.remaining else { return nil }
        func event(_ kind: HistoryResetKind, _ source: String, exact: Double? = nil, inferred: Bool = false) -> HistoryReset {
            HistoryReset(kind: kind, lowerBound: a.time, upperBound: b.time, exactTime: exact, inferred: inferred, source: source)
        }
        // A redeemed identity is stronger evidence than the net available count.
        if let before = a.cards, let after = b.cards,
           before.contains(where: { old in old.status == "available" && after.contains(where: { $0.id == old.id && $0.status == "redeemed" }) }) {
            return event(.card, "card-status:available→redeemed")
        }
        if let oldReset = a.resetsAt, let newReset = b.resetsAt,
           a.time < oldReset, oldReset <= b.time, newReset > oldReset,
           abs((newReset - oldReset) / a.duration - ((newReset - oldReset) / a.duration).rounded()) < 1.0 / a.duration {
            // Exact scheduled boundary is known, but multiple missed cycles remain an interval.
            let single = newReset - oldReset <= a.duration + 1
            return event(.cycle, "scheduled-deadline", exact: single ? oldReset : nil, inferred: true)
        }
        if let oldReset = a.resetsAt, let newReset = b.resetsAt,
           b.time < oldReset, b.remaining == 100, newReset > oldReset,
           abs(newReset - b.time - b.duration) <= 60, cardsUnchanged(a, b) {
            return event(.special, "early-full-reset+full-period+unchanged-complete-cards", inferred: true)
        }
        return event(.unknown, "insufficient-reset-evidence")
    }
    static func cardsUnchanged(_ a: HistoryReading, _ b: HistoryReading) -> Bool {
        guard b.time - a.time <= QuotaHistoryStore.continuityLimit,
              let x = a.cards, let y = b.cards, let n = a.availableCards, let m = b.availableCards,
              x.count == n, y.count == m, n == m,
              x.allSatisfy({ $0.status == "available" && ($0.expiresAt ?? .infinity) > b.time }),
              y.allSatisfy({ $0.status == "available" }), Set(x.map(\.id)) == Set(y.map(\.id)) else { return false }
        return true
    }
}

/// Fresh successful responses are the only input. No countdown/cache/UI ticks enter here.
// Read-only presentation boundary. Collection and versioned persistence stay in the real store.
protocol HistoryDataSource: AnyObject {
    var activeAccount: String? { get }
    var error: String? { get }
    var isSimulated: Bool { get }
    func series() -> [String]
    func visiblePoints(series: String) -> [HistoryPoint]
}
extension HistoryDataSource { var isSimulated: Bool { false } }

enum HistorySourcePolicy {
    static let preferenceKey = "history.useSimulatedData"
    static func usesSimulation(preference: Bool?) -> Bool {
        #if USAGE_TOPBAR_TESTING
        return preference ?? true
        #else
        return false // Release ignores preferences; fixture implementation is not compiled.
        #endif
    }
    static var enabled: Bool {
        #if USAGE_TOPBAR_TESTING
        return usesSimulation(preference: UserDefaults.standard.object(forKey: preferenceKey) as? Bool)
        #else
        return false
        #endif
    }
    static func presentation(real: QuotaHistoryStore) -> any HistoryDataSource {
        #if USAGE_TOPBAR_TESTING
        if enabled { return SimulatedHistorySource() }
        #endif
        return real
    }
}

#if USAGE_TOPBAR_TESTING
// Deterministic relative to a half-hour anchor. Memory-only, no persistence API or timers.
final class SimulatedHistorySource: HistoryDataSource {
    let activeAccount: String? = "simulation-only"
    let error: String? = nil
    let isSimulated = true
    private let points: [HistoryPoint]
    private let key = "codex/secondary/10080.0"
    init(now: Date = Date()) {
        let end = floor(now.timeIntervalSince1970 / 1800) * 1800
        let start = end - 14 * 86400
        // Resets visible in the latest seven days; card and special also in the thumbnail.
        let resets: [Int: HistoryResetKind] = [192: .cycle, 384: .cycle, 528: .card, 624: .special]
        var rows: [HistoryPoint] = []
        var remaining = 94.0
        for index in 0...672 {
            let time = start + Double(index) * 1800
            // 1h missed sample; 5h offline and 3h sleep gaps, including one in the thumbnail.
            if index == 566 || (434...442).contains(index) || (588...592).contains(index) { continue }
            var event: HistoryReset?
            if let kind = resets[index] {
                event = HistoryReset(kind: kind, lowerBound: time-1800, upperBound: time,
                                     exactTime: kind == .cycle ? time : nil,
                                     inferred: kind != .card, source: "simulation")
                remaining = 100
            } else {
                let phase = index % 48
                let decline = phase < 12 ? 0.0 : (phase < 28 ? 0.32 : (phase < 36 ? 1.8 : 0.12))
                remaining = max(5, remaining - decline)
            }
            let gap = rows.last.map { time - $0.reading.time > 1800 } ?? false
            let reading = HistoryReading(account: "simulation-only", series: key, time: time,
                                         remaining: remaining, resetsAt: nil, duration: 604800,
                                         cards: nil, availableCards: nil)
            rows.append(HistoryPoint(reading: reading, gapBefore: gap, event: event,
                                     gapReason: gap ? (index == 593 ? "sleep" : "offline") : nil))
        }
        points = rows
    }
    func series() -> [String] { [key] }
    func visiblePoints(series: String) -> [HistoryPoint] { series == key ? points : [] }
}
#endif

// Startup-only import. The source is an immutable atomic-file snapshot; no polling or source writes.
enum HistoryMigration {
    struct Archive: Codable { let version: Int; let points: [HistoryPoint] }
    struct Result { let added: Int; let conflicts: Int; let backup: URL? }
    private struct Key: Hashable { let account: String; let series: String; let time: Double }
    enum Failure: Error { case invalidArchive, destinationChanged, verificationFailed }
    static var testingURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UsageTopbar Testing/history-v1.json")
    }
    private static func decode(_ data: Data) throws -> Archive {
        let archive = try JSONDecoder().decode(Archive.self, from:data)
        func digest(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
        let sources = Set(["card-status:available→redeemed", "scheduled-deadline", "early-full-reset+full-period+unchanged-complete-cards", "insufficient-reset-evidence"])
        guard archive.version == 1, archive.points.allSatisfy({ p in
            let r=p.reading, parts=r.series.split(separator:"/")
            guard digest(r.account), parts.count==3, parts[0]=="codex",
                  ["primary","secondary"].contains(String(parts[1])), let minutes=Double(parts[2]),
                  minutes>0, minutes<=525600, r.duration==minutes*60,
                  r.time.isFinite, r.time>0, r.remaining.isFinite, (0...100).contains(r.remaining),
                  r.resetsAt.map({ $0.isFinite && $0>0 }) ?? true,
                  r.availableCards.map({ (0...1_000_000).contains($0) }) ?? true else { return false }
            if let cards=r.cards, !cards.allSatisfy({ digest($0.id) && ["available","redeeming","redeemed"].contains($0.status) && ($0.expiresAt.map { $0.isFinite && $0>0 } ?? true) }) { return false }
            if let event=p.event {
                guard sources.contains(event.source), event.lowerBound.isFinite, event.upperBound.isFinite,
                      event.lowerBound<=event.upperBound, event.upperBound<=r.time,
                      event.exactTime.map({ $0.isFinite && $0>=event.lowerBound && $0<=event.upperBound }) ?? true else { return false }
            }
            return true
        }) else { throw Failure.invalidArchive }
        return archive
    }
    @discardableResult
    static func merge(source: URL, destination: URL, now: Date = Date(),
                      afterWrite: () throws -> Void = {}) throws -> Result {
        let fm=FileManager.default
        guard source.standardizedFileURL != destination.standardizedFileURL else { throw Failure.invalidArchive }
        guard fm.fileExists(atPath:source.path) else { return Result(added:0,conflicts:0,backup:nil) }
        let sourceData=try Data(contentsOf:source)
        let incoming=try decode(sourceData)
        let original=fm.fileExists(atPath:destination.path) ? try Data(contentsOf:destination) : nil
        var points=try original.map { try decode($0).points } ?? []
        var keys: [Key:HistoryPoint]=[:]
        for p in points { keys[Key(account:p.reading.account,series:p.reading.series,time:p.reading.time)]=p }
        let cutoff=Calendar(identifier:.gregorian).date(byAdding:.month,value:-3,to:now)!.timeIntervalSince1970
        var added=0, conflicts=0
        for p in incoming.points where p.reading.time>=cutoff && p.reading.time<=now.timeIntervalSince1970+1 {
            let key=Key(account:p.reading.account,series:p.reading.series,time:p.reading.time)
            if let old=keys[key] { if old != p { conflicts+=1 }; continue }
            keys[key]=p;points.append(p);added+=1
        }
        guard added>0 else { return Result(added:0,conflicts:conflicts,backup:nil) }
        points.sort { a,b in
            if a.reading.time != b.reading.time { return a.reading.time < b.reading.time }
            if a.reading.account != b.reading.account { return a.reading.account < b.reading.account }
            return a.reading.series < b.reading.series
        }
        let data=try JSONEncoder().encode(Archive(version:1,points:points))
        let folder=destination.deletingLastPathComponent()
        try fm.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let backup=folder.appendingPathComponent("migration-backups/"+UUID().uuidString)
        try fm.createDirectory(at:backup,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        func save(_ data:Data,to url:URL) throws {
            try data.write(to:url,options:.atomic)
            try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
        }
        try save(sourceData,to:backup.appendingPathComponent("testing-source-v1.json"))
        if let original { try save(original,to:backup.appendingPathComponent("production-before-v1.json")) }
        let report: [String:Any] = ["version":1,"added":added,"conflictsKeptDestination":conflicts,
                                    "destinationPreviouslyExisted":original != nil,"mergedCount":points.count]
        try save(JSONSerialization.data(withJSONObject:report,options:.sortedKeys),to:backup.appendingPathComponent("report.json"))
        // Refuse a concurrently changed destination. Source may continue collecting atomically.
        let current=fm.fileExists(atPath:destination.path) ? try Data(contentsOf:destination) : nil
        guard current==original else { throw Failure.destinationChanged }
        do {
            try save(data,to:destination)
            try afterWrite()
            let written=try Data(contentsOf:destination)
            guard written==data, try decode(written).points==points else { throw Failure.verificationFailed }
        } catch {
            if let original { try save(original,to:destination) }
            else if fm.fileExists(atPath:destination.path) { try fm.removeItem(at:destination) }
            throw error
        }
        return Result(added:added,conflicts:conflicts,backup:backup)
    }
}

final class QuotaHistoryStore: HistoryDataSource {
    private struct Archive: Codable { let version: Int; var points: [HistoryPoint] }
    private(set) var points: [HistoryPoint] = []
    private(set) var activeAccount: String?
    private(set) var error: String?
    var onChange: (() -> Void)?
    var onNewEvent: ((HistoryPoint) -> Void)?
    private var latest: [String: HistoryReading] = [:]
    private var interrupted = Set<String>()
    private var interruptionReasons: [String: String] = [:]
    private var needsFreshStart = true
    private var freshStartReason = "startup"
    private let file: URL?
    private var writable = true
    private var pendingPersistence = false
    // Store state stays on the main thread; only immutable snapshots cross this queue.
    private let persistenceQueue = DispatchQueue(label: "usage-topbar.history", qos: .utility)
    private var revision: UInt64 = 0
    private var writeGeneration: UInt64 = 0
    private var writing = false
    private var migrationWarning: String?
    static let interval: Double = 1800
    static let continuityLimit: Double = 90

    init(file: URL? = QuotaHistoryStore.defaultURL, now: Date = Date(), migrationSource: URL? = nil) {
        self.file = file
        // Explicit injection supports isolated upgrade rehearsals; only release has an automatic source.
        #if USAGE_TOPBAR_TESTING
        let source = migrationSource
        #else
        let source = migrationSource ?? (file?.standardizedFileURL == Self.defaultURL.standardizedFileURL ? HistoryMigration.testingURL : nil)
        #endif
        if let file, let source {
            do { try HistoryMigration.merge(source:source,destination:file,now:now) }
            catch {
                migrationWarning = "测试版历史接续失败，请检查历史文件与 migration-backups，修复后重启重试"
                self.error = migrationWarning
            }
        }
        if let file, FileManager.default.fileExists(atPath: file.path) {
            do {
                let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                guard archive.version == 1, archive.points.allSatisfy({ p in
                    p.reading.time.isFinite && p.reading.remaining.isFinite && (0...100).contains(p.reading.remaining)
                    && p.reading.duration > 0 && p.reading.duration.isFinite
                }) else { throw CocoaError(.fileReadCorruptFile) }
                points = archive.points.sorted { $0.reading.time < $1.reading.time }
                pendingPersistence = prune(at: now)
            } catch { self.error = "历史文件无法读取，已保留原文件"; writable = false }
        }
        // Restart always creates a gap, even when the last point is recent.
    }
    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppVariant.storageFolder).appendingPathComponent("history-v1.json")
    }
    func receive(_ readings: [HistoryReading], now: Date) {
        guard !readings.isEmpty else { unavailable(); activeAccount = nil; freshStartReason = "identity-unavailable"; onChange?(); return }
        let account = readings[0].account
        guard readings.allSatisfy({ $0.account == account }) else { unavailable(); return }
        if activeAccount != account { if activeAccount != nil { freshStartReason = "account-change" }; unavailable(); latest.removeAll(); interrupted.removeAll(); interruptionReasons.removeAll(); activeAccount = account; needsFreshStart = true }
        let incoming = Set(readings.map(\.series))
        var changed = false
        for key in latest.keys where !incoming.contains(key) {
            if let last = latest[key], points.last(where: { $0.reading.account == account && $0.reading.series == key })?.reading.time != last.time {
                points.append(HistoryPoint(reading: last, gapBefore: false, event: nil)); changed = true
            }
            interrupted.insert(key)
            interruptionReasons[key] = "missing-window"
        }
        for reading in readings {
            guard reading.time.isFinite, reading.time <= now.timeIntervalSince1970 + 1,
                  now.timeIntervalSince1970 - reading.time <= 60,
                  reading.remaining.isFinite, (0...100).contains(reading.remaining) else { continue }
            let persisted = points.last { $0.reading.account == account && $0.reading.series == reading.series }
            let previous = latest[reading.series] ?? persisted?.reading
            guard previous == nil || reading.time > previous!.time else { continue }
            let gap = needsFreshStart || interrupted.contains(reading.series)
                || (latest[reading.series].map { reading.time - $0.time > Self.continuityLimit } ?? true)
            let event = previous.flatMap { HistoryResetClassifier.classify(previous: $0, current: reading) }
            // Unknown upward corrections also break the line; never celebrate them.
            let due = persisted.map { reading.time - $0.reading.time >= Self.interval } ?? true
            if gap || due || event != nil {
                if gap || event != nil, let last = latest[reading.series], persisted?.reading.time != last.time {
                    points.append(HistoryPoint(reading: last, gapBefore: false, event: nil))
                }
                let reason: String? = !gap ? nil : (needsFreshStart ? freshStartReason : interruptionReasons[reading.series] ?? "fresh-read-gap-over-90s")
                let point = HistoryPoint(reading: reading, gapBefore: gap, event: event, gapReason: reason)
                points.append(point); changed = true
                if let event, event.kind != .unknown { onNewEvent?(point) }
            }
            latest[reading.series] = reading
            interrupted.remove(reading.series)
            interruptionReasons.removeValue(forKey: reading.series)
        }
        needsFreshStart = false
        if prune(at: now) { changed = true }
        if changed { revision += 1; pendingPersistence = true }
        let previousError = error
        if pendingPersistence { persist() }
        if changed || error != previousError { onChange?() }
    }
    func unavailable(reason: String = "read-unavailable") {
        var changed = false
        for (series, reading) in latest {
            if points.last(where: { $0.reading.account == reading.account && $0.reading.series == series })?.reading.time != reading.time {
                points.append(HistoryPoint(reading: reading, gapBefore: false, event: nil)); changed = true
            }
            interrupted.insert(series)
            interruptionReasons[series] = reason
        }
        if changed { revision += 1; pendingPersistence = true }
        if pendingPersistence { persist() }
        onChange?()
    }
    // Sleep/termination must not depend on a main-queue completion running later.
    func flushPersistence() { if pendingPersistence { persist(wait: true) } }
    func shutdown() { unavailable(reason: "shutdown"); flushPersistence() }
    func series() -> [String] {
        Array(Set(points.filter { $0.reading.account == activeAccount }.map { $0.reading.series })).sorted()
    }
    func visiblePoints(series: String) -> [HistoryPoint] {
        var result: [HistoryPoint] = []
        var crossedAccount = false
        for point in points.sorted(by: { $0.reading.time < $1.reading.time }) {
            guard point.reading.account == activeAccount else {
                if !result.isEmpty { crossedAccount = true }
                continue
            }
            guard point.reading.series == series else { continue }
            var displayed = point
            if crossedAccount { displayed.gapReason = "account-change"; displayed.gapBefore = true }
            result.append(displayed); crossedAccount = false
        }
        return result
    }
    @discardableResult private func prune(at date: Date) -> Bool {
        let before = points.count
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .month, value: -3, to: date)!.timeIntervalSince1970
        points.removeAll { $0.reading.time < cutoff }
        return points.count != before
    }
    private func persist(wait: Bool = false) {
        guard let file, writable, wait || !writing else { return }
        writing = true
        writeGeneration += 1
        let generation = writeGeneration, savedRevision = revision, snapshot = points
        let write = { () -> Bool in
            do {
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                       attributes: [.posixPermissions: 0o700])
                let data = try JSONEncoder().encode(Archive(version: 1, points: snapshot.sorted { $0.reading.time < $1.reading.time }))
                try data.write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                return true
            } catch { return false }
        }
        let complete: (Bool) -> Void = { [weak self] succeeded in
            guard let self, self.writeGeneration == generation else { return }
            self.writing = false
            let previousError = self.error
            self.error = succeeded ? self.migrationWarning : "历史保存失败"
            self.pendingPersistence = !succeeded || self.revision != savedRevision
            if self.error != previousError { self.onChange?() }
            // Coalesce changes during a write into one latest snapshot. A failed
            // unchanged snapshot retries on the next reading, never in a tight loop.
            if self.revision != savedRevision { self.persist() }
        }
        if wait {
            complete(persistenceQueue.sync(execute: write))
        } else {
            persistenceQueue.async {
                let succeeded = write()
                DispatchQueue.main.async { complete(succeeded) }
            }
        }
    }
}
