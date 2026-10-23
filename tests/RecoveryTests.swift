import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(),message) }
let base=Date(timeIntervalSince1970:1_800_000_000)
let available=HistoryCard(id:"fixture-card",status:"available",expiresAt:nil)
let redeemed=HistoryCard(id:"fixture-card",status:"redeemed",expiresAt:nil)
func reading(_ t:Double,_ value:Double,reset:Double?=604800,cards:[HistoryCard]?=[available],count:Int?=1,account:String="a") -> HistoryReading {
 HistoryReading(account:account,series:"codex/secondary/10080.0",time:base.timeIntervalSince1970+t,remaining:value,
 resetsAt:reset.map {base.timeIntervalSince1970+$0},duration:604800,cards:cards,availableCards:count)
}
func feed(_ s:QuotaHistoryStore,_ r:HistoryReading) { s.receive([r],now:Date(timeIntervalSince1970:r.time)) }
let before=reading(0,0),after=reading(60,100,reset:nil)
let store=QuotaHistoryStore(file:nil,now:base)
var events=0;store.onNewEvent={_ in events+=1}
feed(store,before);feed(store,after);feed(store,reading(1860,100))
let special=store.points[1].event!
check(special.kind == .special && special.inferred && special.exactTime==nil,"early full recovery with unchanged complete cards is special; new deadline not required")
check(events==1 && store.points.last!.event==nil,"repeated 100 does not repeat reset")
let points=store.visiblePoints(series:before.series)
check(points[1].event==special,"live and replay use identical classification")
let connector=HistoryChartGeometry.resetConnector(points,at:1,from:CGPoint(x:0,y:100),to:CGPoint(x:80,y:0))
check(connector?.0.x==80 && connector?.1.x==80,"supported reset connector at first recovery observation")
check(!HistoryChartGeometry.resetBands(connectors:[connector!],plot:CGRect(x:0,y:0,width:100,height:100),viewportWidth:100).isEmpty,"supported reset has green band")
let cycleBefore=reading(604790,0),cycleAfter=reading(604810,100,reset:1209600)
check(HistoryResetClassifier.classify(previous:cycleBefore,current:cycleAfter)?.kind == .cycle,"observed scheduled cycle keeps automatic reset")
check(HistoryResetClassifier.classify(previous:cycleBefore,current:cycleAfter,gap:true)?.kind == .unknown,"gap spanning old deadline cannot establish reset type")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,cards:[redeemed],count:0),gap:true)?.kind == .card,"used card takes priority")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,cards:nil,count:nil),gap:true)?.kind == .unknown,"unknown cards are not unused cards")
check(HistoryResetClassifier.classify(previous:reading(0,0,reset:nil),current:after,gap:true)?.kind == .unknown,"missing old deadline cannot be filled from current deadline")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,account:"b"),gap:true)==nil,"account isolation")
check(HistoryResetClassifier.classify(previous:before,current:after,gap:true,gapReason:"account-change")==nil,"switch back cannot create reset")
struct Archive:Codable {let version:Int;let points:[HistoryPoint]}
let file=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("legacy.json")
let legacyEvent=HistoryReset(kind:.unknown,lowerBound:before.time,upperBound:after.time,exactTime:nil,inferred:true,source:"gap-recovery-full")
for known in [true,false] {
 let a=known ? before : reading(0,0,reset:nil,cards:nil,count:nil)
 let b=known ? after : reading(10800,100,reset:nil,cards:nil,count:nil)
 let old=[HistoryPoint(reading:a,gapBefore:false,event:nil),HistoryPoint(reading:b,gapBefore:!known,event:legacyEvent,gapReason:"read-unavailable")]
 let data=try JSONEncoder().encode(Archive(version:1,points:old));try data.write(to:file)
 let replay=QuotaHistoryStore(file:file,now:base.addingTimeInterval(10800));feed(replay,b)
 let visible=replay.visiblePoints(series:a.series)
 check(visible.last!.event?.kind == (known ? .special:.unknown),"legacy replay classifies only with reliable evidence")
 check(replay.points[0].reading.resetsAt==a.resetsAt,"historical deadline preserved, missing stays nil")
 if !known { check(HistoryChartGeometry.resetConnector(visible,at:1,from:.zero,to:CGPoint(x:20,y:30)) != nil && visible.last!.event?.kind == .unknown,"legacy observed recovery retains unknown marker and band") }
 let unchanged=try Data(contentsOf:file);check(unchanged==data,"replay does not rewrite history")
}
let raw:[String:Any] = ["accountId":"fixture","rateLimits":["primary":["usedPercent":100,"windowDurationMins":10080,"resetsAt":base.timeIntervalSince1970+604800]]]
let parsed=HistoryReading.parse(raw,at:base).first!
let roundTrip=try JSONDecoder().decode(HistoryReading.self,from:JSONEncoder().encode(parsed))
check(roundTrip.resetsAt==base.timeIntervalSince1970+604800,"sampling parses and persists its own scheduled deadline")
print("PASS early special/reset icon and band, scheduled cycle/card priority, unknown recovery markers, repeat/account isolation, legacy replay and historical deadline persistence")

// Old cycle labels must also be reconsidered when the saved interval crosses a gap.
let oldCycle=HistoryReset(kind:.cycle,lowerBound:cycleBefore.time,upperBound:cycleAfter.time,exactTime:base.timeIntervalSince1970+604800,inferred:true,source:"scheduled-deadline")
let cycleRows=[HistoryPoint(reading:cycleBefore,gapBefore:false,event:nil),HistoryPoint(reading:cycleAfter,gapBefore:true,event:oldCycle,gapReason:"read-unavailable")]
try JSONEncoder().encode(Archive(version:1,points:cycleRows)).write(to:file)
let cycleReplay=QuotaHistoryStore(file:file,now:base.addingTimeInterval(604810));feed(cycleReplay,cycleAfter)
check(cycleReplay.visiblePoints(series:before.series).last!.event?.kind == .unknown,"old cycle label cannot override ambiguous saved gap evidence")
print("PASS live/replay parity and reconsideration of unsupported old classifications")

for cards:[HistoryCard] in [[],[available]] {
 let a=reading(0,0,cards:cards,count:cards.count),b=reading(10800,100,cards:cards,count:cards.count)
 for gap in [false,true] {
  check(HistoryResetClassifier.classify(previous:a,current:b,gap:gap)?.kind == .special,"complete unchanged snapshots before old deadline permit inferred special across gap")
 }
}
check(HistoryResetClassifier.classify(previous:before,current:after,gap:true)?.kind == .special,"short explicit gap does not block early special")
print("PASS early recovery across gaps with complete empty/populated card snapshots")

// Sanitized reproduction: only observed dates/percentages, synthetic identities/cards.
let iso=ISO8601DateFormatter();iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
func stamp(_ value:String)->Double { iso.date(from:value)!.timeIntervalSince1970 }
let t0=stamp("2026-10-23T01:05:12.997+08:00"),t1=stamp("2026-10-23T12:04:07.538+08:00")
let oldDeadline=stamp("2026-10-27T14:33:02.000+08:00"),newDeadline=stamp("2026-10-30T01:11:19.000+08:00")
let complete=[HistoryCard(id:"synthetic-a",status:"available",expiresAt:stamp("2027-01-01T00:00:00.000+08:00")),HistoryCard(id:"synthetic-b",status:"available",expiresAt:nil)]
func observed(_ time:Double,_ value:Double,deadline:Double?,cards:[HistoryCard]?=complete,count:Int?=2,account:String="sanitized",series:String="codex/secondary/10080.0")->HistoryReading {
 HistoryReading(account:account,series:series,time:time,remaining:value,resetsAt:deadline,duration:604800,cards:cards,availableCards:count)
}
let realBefore=observed(t0,46,deadline:oldDeadline),realAfter=observed(t1,100,deadline:newDeadline)
let classified=HistoryResetClassifier.classify(previous:realBefore,current:realAfter,gap:true,gapReason:"read-unavailable")!
check(classified.kind == .special && classified.inferred && classified.exactTime == nil,"sanitized 46 to 100 after 10h58m before saved deadline is special")
check(classified.lowerBound==t0 && classified.upperBound==t1,"observed interval preserved")
for t in [t1,oldDeadline-0.001] {
 check(HistoryResetClassifier.classify(previous:realBefore,current:observed(t,100,deadline:nil),gap:true)?.kind == .special,"new deadline unnecessary, strictly before old boundary")
}
for t in [oldDeadline,oldDeadline+1,oldDeadline+604800] {
 let event=HistoryResetClassifier.classify(previous:realBefore,current:observed(t,100,deadline:t+604800),gap:true)!
 check(event.kind == .unknown && event.showsReset && event.exactTime==nil,"crossed old boundary remains visible unknown, never inferred natural")
}
for b in [observed(t1,100,deadline:newDeadline,cards:nil,count:nil),observed(t1,100,deadline:newDeadline,cards:[complete[0]],count:2),observed(t1,100,deadline:newDeadline,cards:[complete[0],complete[0]]),observed(t1,100,deadline:newDeadline,cards:[HistoryCard(id:"synthetic-a",status:"available",expiresAt:nil),complete[1]])] {
 check(HistoryResetClassifier.classify(previous:realBefore,current:b,gap:true)?.kind == .unknown,"missing/truncated/duplicate/changed expiry evidence cannot imply unused cards")
}
let noDate=observed(t0,46,deadline:nil)
check(HistoryResetClassifier.classify(previous:noDate,current:realAfter,gap:true)?.kind == .unknown,"new deadline cannot replace missing saved deadline")
let spent=observed(t1,100,deadline:newDeadline,cards:[HistoryCard(id:"synthetic-a",status:"redeemed",expiresAt:complete[0].expiresAt),complete[1]],count:1)
check(HistoryResetClassifier.classify(previous:realBefore,current:spent,gap:true)?.kind == .card,"explicit card usage wins")
for b in [observed(t1,46,deadline:newDeadline),observed(t1,40,deadline:newDeadline),observed(t1,100,deadline:newDeadline,account:"other"),observed(t1,100,deadline:newDeadline,series:"codex/primary/300.0")] {
 check(HistoryResetClassifier.classify(previous:realBefore,current:b,gap:true)==nil,"ordinary gap, decline and identity changes never create reset markers")
}
let correction=HistoryResetClassifier.classify(previous:realBefore,current:observed(t1,47,deadline:newDeadline),gap:true)!
check(correction.kind == .unknown && !correction.showsReset,"small unexplained correction is not an observed full recovery")
let oldUnknown=HistoryReset(kind:.unknown,lowerBound:t0,upperBound:t1,exactTime:nil,inferred:false,source:"insufficient-reset-evidence")
let savedRows=[HistoryPoint(reading:realBefore,gapBefore:false,event:nil),HistoryPoint(reading:realAfter,gapBefore:true,event:oldUnknown,gapReason:"read-unavailable")]
let saved=try JSONEncoder().encode(Archive(version:1,points:savedRows));try saved.write(to:file)
let restored=QuotaHistoryStore(file:file,now:Date(timeIntervalSince1970:t1));feed(restored,realAfter)
let derived=restored.visiblePoints(series:realBefore.series)
check(derived.last!.event?.kind == .special && derived.last!.gapBefore && derived.last!.gapReason=="read-unavailable","old unknown reclassified only in presentation, gap retained")
check(restored.points.last!.event==oldUnknown,"stored event remains untouched")
let preserved=try Data(contentsOf:file)
check(preserved==saved,"original archive byte-for-byte unchanged by replay")
print("PASS sanitized overnight recovery, strict old deadline boundary, missing/changed card fields, card priority, account/series isolation, ordinary gaps, read-only legacy reclassification")
