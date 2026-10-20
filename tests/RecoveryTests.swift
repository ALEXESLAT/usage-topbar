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
let before=reading(0,0),after=reading(10800,100,reset:nil)
let store=QuotaHistoryStore(file:nil,now:base)
var events=0;store.onNewEvent={_ in events+=1}
feed(store,before);store.unavailable();feed(store,after);feed(store,reading(12600,100))
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
check(HistoryResetClassifier.classify(previous:cycleBefore,current:cycleAfter,gap:true)?.showsReset==false,"gap spanning old deadline cannot establish reset type")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,cards:[redeemed],count:0),gap:true)?.kind == .card,"used card takes priority")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,cards:nil,count:nil),gap:true)?.showsReset==false,"unknown cards are not unused cards")
check(HistoryResetClassifier.classify(previous:reading(0,0,reset:nil),current:after,gap:true)?.showsReset==false,"missing old deadline cannot be filled from current deadline")
check(HistoryResetClassifier.classify(previous:before,current:reading(10800,100,account:"b"),gap:true)==nil,"account isolation")
check(HistoryResetClassifier.classify(previous:before,current:after,gap:true,gapReason:"account-change")==nil,"switch back cannot create reset")
struct Archive:Codable {let version:Int;let points:[HistoryPoint]}
let file=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("legacy.json")
let legacyEvent=HistoryReset(kind:.unknown,lowerBound:before.time,upperBound:after.time,exactTime:nil,inferred:true,source:"gap-recovery-full")
for known in [true,false] {
 let a=known ? before : reading(0,0,reset:nil,cards:nil,count:nil)
 let b=known ? after : reading(10800,100,reset:nil,cards:nil,count:nil)
 let old=[HistoryPoint(reading:a,gapBefore:false,event:nil),HistoryPoint(reading:b,gapBefore:true,event:legacyEvent,gapReason:"read-unavailable")]
 let data=try JSONEncoder().encode(Archive(version:1,points:old));try data.write(to:file)
 let replay=QuotaHistoryStore(file:file,now:base.addingTimeInterval(10800));feed(replay,b)
 let visible=replay.visiblePoints(series:a.series)
 check(visible.last!.event?.kind == (known ? .special:.unknown),"legacy replay classifies only with reliable evidence")
 check(replay.points[0].reading.resetsAt==a.resetsAt,"historical deadline preserved, missing stays nil")
 if !known { check(HistoryChartGeometry.resetConnector(visible,at:1,from:.zero,to:.zero)==nil && visible.last!.event?.showsReset==false,"legacy forced recovery loses reset marker and band") }
 let unchanged=try Data(contentsOf:file);check(unchanged==data,"replay does not rewrite history")
}
let raw:[String:Any] = ["accountId":"fixture","rateLimits":["primary":["usedPercent":100,"windowDurationMins":10080,"resetsAt":base.timeIntervalSince1970+604800]]]
let parsed=HistoryReading.parse(raw,at:base).first!
let roundTrip=try JSONDecoder().decode(HistoryReading.self,from:JSONEncoder().encode(parsed))
check(roundTrip.resetsAt==base.timeIntervalSince1970+604800,"sampling parses and persists its own scheduled deadline")
print("PASS early special/reset icon and band, scheduled cycle/card priority, uncertain gap/no forced marker, repeat/account isolation, legacy replay and historical deadline persistence")

// Old cycle labels must also be reconsidered when the saved interval crosses a gap.
let oldCycle=HistoryReset(kind:.cycle,lowerBound:cycleBefore.time,upperBound:cycleAfter.time,exactTime:base.timeIntervalSince1970+604800,inferred:true,source:"scheduled-deadline")
let cycleRows=[HistoryPoint(reading:cycleBefore,gapBefore:false,event:nil),HistoryPoint(reading:cycleAfter,gapBefore:true,event:oldCycle,gapReason:"read-unavailable")]
try JSONEncoder().encode(Archive(version:1,points:cycleRows)).write(to:file)
let cycleReplay=QuotaHistoryStore(file:file,now:base.addingTimeInterval(604810));feed(cycleReplay,cycleAfter)
check(cycleReplay.visiblePoints(series:before.series).last!.event?.kind == .unknown,"old cycle label cannot override ambiguous saved gap evidence")
print("PASS live/replay parity and reconsideration of unsupported old classifications")
