import Foundation
func expect(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
let base = Date(timeIntervalSince1970: 1_800_000_000)
func reading(_ t: Double, _ value: Double = 50, account: String = "a", series: String = "codex/primary/10080.0", reset: Double? = nil, cards: [HistoryCard]? = [], count: Int? = 0) -> HistoryReading {
    HistoryReading(account:account,series:series,time:base.timeIntervalSince1970+t,remaining:value,resetsAt:reset ?? base.timeIntervalSince1970+604800,duration:604800,cards:cards,availableCards:count)
}
func feed(_ store:QuotaHistoryStore, _ r:HistoryReading) { store.receive([r],now:Date(timeIntervalSince1970:r.time)) }
let dir=URL(fileURLWithPath:CommandLine.arguments[1]);let file=dir.appendingPathComponent("history.json")
let store=QuotaHistoryStore(file:file,now:base)
feed(store,reading(0)); expect(store.points.count==1,"initial fresh read")
for t in stride(from:30.0,through:1770,by:30) { feed(store,reading(t)) }
expect(store.points.count==1,"30 minute throttle")
feed(store,reading(1800));expect(store.points.count==2 && !store.points[1].gapBefore,"equal successful readings remain solid")
feed(store,reading(1800));expect(store.points.count==2,"duplicate response ignored")
feed(store,reading(1830));store.unavailable();expect(store.points.last!.reading.time==base.timeIntervalSince1970+1830,"last fresh evidence retained at interruption")
feed(store,reading(5400,40));expect(store.points.last!.gapBefore && store.points.last!.reading.remaining==40,"offline recovery gap, no zero")
store.shutdown()
let restarted=QuotaHistoryStore(file:file,now:base.addingTimeInterval(5430));feed(restarted,reading(5430,40))
expect(restarted.points.last!.gapBefore,"restart creates gap")
feed(restarted,reading(5460,100,account:"b"));expect(restarted.visiblePoints(series:"codex/primary/10080.0").count==1,"account isolation")
expect(restarted.points.last!.event==nil,"account switch is not reset")
feed(restarted,reading(5490,100,account:"b",series:"codex/secondary/300.0"));expect(restarted.points.last!.event==nil,"cycle type switch not reset")
let cutoff=Calendar(identifier:.gregorian).date(byAdding:.month,value:3,to:base.addingTimeInterval(6000))!
let pruned=QuotaHistoryStore(file:file,now:cutoff);expect(pruned.points.isEmpty,"calendar three month retention")
let expired=HistoryCard(id:"old",status:"available",expiresAt:base.timeIntervalSince1970+100)
let used=HistoryCard(id:"old",status:"redeemed",expiresAt:base.timeIntervalSince1970+100)
let fresh=HistoryCard(id:"new",status:"available",expiresAt:nil)
let a=reading(0,20,cards:[expired],count:1)
let b=reading(300,100,reset:base.timeIntervalSince1970+605100,cards:[],count:0)
expect(HistoryResetClassifier.classify(previous:a,current:b)?.kind == .unknown,"expiry not card usage or special")
let c=reading(60,100,reset:base.timeIntervalSince1970+604860,cards:[used,fresh],count:1)
expect(HistoryResetClassifier.classify(previous:a,current:c)?.kind == .card,"redeemed identity despite replacement count")
let natural=reading(604810,100,reset:base.timeIntervalSince1970+1209600)
let cycle=HistoryResetClassifier.classify(previous:reading(604790,10),current:natural)
expect(cycle?.kind == .cycle && cycle?.exactTime==base.timeIntervalSince1970+604800,"exact cycle boundary")
let special=HistoryResetClassifier.classify(previous:reading(259170,10),current:reading(259200,100,reset:base.timeIntervalSince1970+864000))
expect(special?.kind == .special && special?.inferred==true && special?.exactTime==nil,"special is inferred interval")
let missing=HistoryResetClassifier.classify(previous:reading(0,10,cards:nil,count:nil),current:reading(259200,100,reset:base.timeIntervalSince1970+864000,cards:nil,count:nil))
expect(missing?.kind == .unknown,"missing card evidence cannot claim special")
expect(HistoryResetClassifier.classify(previous:reading(0,10),current:reading(30,15))?.kind == .unknown,"ordinary correction no celebration")
var events=0
let eventStore=QuotaHistoryStore(file:nil,now:base);eventStore.onNewEvent={_ in events+=1}
feed(eventStore,reading(0,10));feed(eventStore,reading(30,100,reset:base.timeIntervalSince1970+604830));feed(eventStore,reading(60,100,reset:base.timeIntervalSince1970+604830))
expect(events==1,"deduplicated event")
let raw:[String:Any] = ["accountId":"not-persisted-raw-id","rateLimits":["primary":["usedPercent":25,"windowDurationMins":300,"resetsAt":base.timeIntervalSince1970+18000]]]
let parsed=HistoryReading.parse(raw,at:base)
expect(parsed.count==1 && parsed[0].remaining==75 && parsed[0].account.count==64,"schema parse and digest")
let encoded = try JSONEncoder().encode(parsed)
expect(!String(data:encoded,encoding:.utf8)!.contains("not-persisted-raw-id"),"no raw account persisted")
expect(HistoryReading.parse(["rateLimits":raw["rateLimits"]!],at:base).isEmpty,"no account means no record")
let invalid=QuotaHistoryStore(file:nil,now:base);invalid.receive([reading(0)],now:base.addingTimeInterval(120))
expect(invalid.points.isEmpty,"stale observation rejected")
let corrupt=dir.appendingPathComponent("corrupt.json");try Data("broken".utf8).write(to:corrupt)
let broken=QuotaHistoryStore(file:corrupt,now:base);feed(broken,reading(0));let saved = try String(contentsOf:corrupt,encoding:.utf8);expect(saved=="broken","never overwrite damaged history")
print("PASS history: fresh/throttle, persistence/restart, offline/unknown, account/type isolation, exact cycles, expired/redeemed/replaced cards, inferred/unknown resets, dedup, three calendar months, digest and corrupt-file preservation")

let acrossGap=HistoryResetClassifier.classify(previous:reading(0,10),current:reading(259200,100,reset:base.timeIntervalSince1970+864000))
expect(acrossGap?.kind == .special,"early recovery with complete unchanged cards supports inferred special across gap")
let staleWindow:[String:Any] = ["accountId":"fixture","rateLimits":["primary":["usedPercent":0,"windowDurationMins":300,"resetsAt":base.timeIntervalSince1970-1]]]
expect(HistoryReading.parse(staleWindow,at:base).isEmpty,"expired quota not saved as fresh")
print("PASS expired window and inferred early reset across offline interval")

let reasons=QuotaHistoryStore(file:nil,now:base)
feed(reasons,reading(0));expect(reasons.points.last!.gapReason=="startup","startup reason")
reasons.unavailable(reason:"sleep");feed(reasons,reading(30))
expect(reasons.points.last!.gapReason=="sleep","sleep reason retained without editing readings")
feed(reasons,reading(60,account:"other"));expect(reasons.points.last!.gapReason=="account-change","account boundary reason")
print("PASS additive gap reasons with old history compatibility")

let switchBack=QuotaHistoryStore(file:nil,now:base)
feed(switchBack,reading(0,account:"a"));feed(switchBack,reading(30,account:"b"));feed(switchBack,reading(60,account:"a"))
expect(switchBack.visiblePoints(series:"codex/primary/10080.0").last!.gapReason=="account-change","returning account keeps boundary in filtered view")
print("PASS filtered account re-entry retains a hard boundary")

// A failed atomic write must retry on the next fresh read, before the next 30m sample.
let blockedParent=dir.appendingPathComponent("retry-parent")
try Data("blocked".utf8).write(to:blockedParent)
let retryFile=blockedParent.appendingPathComponent("history.json")
let retryStore=QuotaHistoryStore(file:retryFile,now:base)
feed(retryStore,reading(0));retryStore.flushPersistence();expect(retryStore.error != nil,"injected write failure")
try FileManager.default.removeItem(at:blockedParent)
feed(retryStore,reading(30));retryStore.flushPersistence()
expect(FileManager.default.fileExists(atPath:retryFile.path) && retryStore.error==nil,"failed write retries before next sample")
let retryArchive=try JSONSerialization.jsonObject(with:Data(contentsOf:retryFile)) as! [String:Any]
expect((retryArchive["points"] as! [Any]).count==1,"retry does not add an early sample")
struct RetentionArchive:Codable {let version:Int;let points:[HistoryPoint]}
let expiryFile=dir.appendingPathComponent("retention-boundary.json")
let expiryCutoff=Calendar(identifier:.gregorian).date(byAdding:.month,value:-3,to:base)!.timeIntervalSince1970
let old=reading(expiryCutoff+15-base.timeIntervalSince1970)
try JSONEncoder().encode(RetentionArchive(version:1,points:[HistoryPoint(reading:old,gapBefore:true,event:nil)])).write(to:expiryFile)
let expiryStore=QuotaHistoryStore(file:expiryFile,now:base)
feed(expiryStore,reading(0));feed(expiryStore,reading(30))
expiryStore.flushPersistence()
let diskExpiry=try JSONDecoder().decode(RetentionArchive.self,from:Data(contentsOf:expiryFile))
expect(diskExpiry.points==expiryStore.points && diskExpiry.points.count==1,"retention-only change is persisted before next sample")
print("PASS failed-write retry without oversampling and retention-only durable pruning")

// Drive actual main-queue completions: file assertions alone cannot validate retries.
func eventually(_ message: String, _ predicate: () -> Bool) {
    let deadline = Date().addingTimeInterval(3)
    while !predicate() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.005)) }
    expect(predicate(), message)
}
let asyncParent=dir.appendingPathComponent("async-retry")
try Data("blocked".utf8).write(to:asyncParent)
let asyncFile=asyncParent.appendingPathComponent("history.json")
let asyncStore=QuotaHistoryStore(file:asyncFile,now:base)
var errorNotifications=0
asyncStore.onChange = { expect(Thread.isMainThread,"completion delivered on main thread"); if asyncStore.error != nil { errorNotifications += 1 } }
feed(asyncStore,reading(0))
expect(asyncStore.error == nil,"receive returns before disk failure completion")
eventually("async disk failure reported") { asyncStore.error != nil }
let notificationsAfterFailure=errorNotifications
RunLoop.current.run(until:Date().addingTimeInterval(0.05))
expect(errorNotifications==notificationsAfterFailure,"failed unchanged write does not self-retry")
try FileManager.default.removeItem(at:asyncParent)
feed(asyncStore,reading(30))
eventually("next fresh read retries asynchronously") { asyncStore.error == nil && FileManager.default.fileExists(atPath:asyncFile.path) }
expect(asyncStore.points.count==1,"async retry preserves sampling interval")
asyncStore.onChange=nil

let burstFile=dir.appendingPathComponent("burst.json")
let burst=QuotaHistoryStore(file:burstFile,now:base)
for i in 0..<40 { feed(burst,reading(Double(i)*30,account:i % 2 == 0 ? "a":"b")) }
func diskPoints(_ file:URL)->[HistoryPoint]? { (try? Data(contentsOf:file)).flatMap { try? JSONDecoder().decode(RetentionArchive.self,from:$0).points } }
eventually("coalesced writes retain latest account and gap evidence") { diskPoints(burstFile)==burst.points }
feed(burst,reading(1200,account:"c"))
burst.shutdown()
let shutdownPoints=burst.points
expect(diskPoints(burstFile)==shutdownPoints,"shutdown drains serial writes and saves latest snapshot")
RunLoop.current.run(until:Date().addingTimeInterval(0.05))
expect(diskPoints(burstFile)==shutdownPoints && burst.error==nil,"late completion cannot undo shutdown flush")
feed(burst,reading(1230,account:"c"));burst.unavailable(reason:"sleep");burst.flushPersistence()
expect(diskPoints(burstFile)==burst.points,"sleep flush includes final fresh reading")
print("PASS asynchronous retry, main-thread notification, coalesced account changes, shutdown ordering and sleep flush")

let cacheStore = QuotaHistoryStore(file: nil)
let cacheNow = Date()
func cacheReading(_ account: String, _ time: Double, _ remaining: Double) -> HistoryReading {
 HistoryReading(account: account, series: "weekly", time: time, remaining: remaining, resetsAt: time+604800, duration: 604800, cards: [], availableCards: 0)
}
cacheStore.receive([cacheReading("a", cacheNow.timeIntervalSince1970-30, 46)], now: cacheNow)
let cachedA = cacheStore.visiblePoints(series: "weekly")
precondition(cacheStore.visiblePoints(series: "weekly") == cachedA)
cacheStore.receive([cacheReading("a", cacheNow.timeIntervalSince1970, 100)], now: cacheNow)
precondition(cacheStore.visiblePoints(series: "weekly").last?.event?.kind == .special)
cacheStore.receive([cacheReading("b", cacheNow.timeIntervalSince1970, 20)], now: cacheNow)
precondition(cacheStore.visiblePoints(series: "weekly").allSatisfy { $0.reading.account == "b" })
cacheStore.receive([], now: cacheNow)
precondition(cacheStore.visiblePoints(series: "weekly").isEmpty)
print("PASS derived cache invalidates on revision, account switch and missing identity")
