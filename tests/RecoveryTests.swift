import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(),message) }
let base=Date(timeIntervalSince1970:1_800_000_000)
func reading(_ t:Double,_ value:Double,account:String="a") -> HistoryReading {
 HistoryReading(account:account,series:"codex/secondary/10080.0",time:base.timeIntervalSince1970+t,remaining:value,resetsAt:nil,duration:604800,cards:nil,availableCards:nil)
}
func feed(_ s:QuotaHistoryStore,_ r:HistoryReading) { s.receive([r],now:Date(timeIntervalSince1970:r.time)) }
let store=QuotaHistoryStore(file:nil,now:base)
var count=0;store.onNewEvent={_ in count+=1}
feed(store,reading(0,0));store.unavailable();feed(store,reading(10800,100));feed(store,reading(12600,100))
let e=store.points[1].event!
check(e.showsReset && e.inferred && e.kind == .unknown && e.exactTime == nil,"full recovery remains inferred with unknown cause/time")
check(count==1 && store.points.last!.event==nil,"repeated 100 does not repeat reset")
let points=store.visiblePoints(series:reading(0,0).series)
let connector=HistoryChartGeometry.resetConnector(points,at:1,from:CGPoint(x:0,y:100),to:CGPoint(x:80,y:0))
check(connector?.0.x==80 && connector?.1.x==80,"green connector at first recovery observation")
check(!HistoryChartGeometry.resetBands(connectors:[connector!],plot:CGRect(x:0,y:0,width:100,height:100),viewportWidth:100).isEmpty,"green band exists")
check(points.filter{$0.event?.showsReset==true}.count==1,"one marker")
check(HistoryChartGeometry.resetConnector(points,at:2,from:.zero,to:.zero)==nil,"no repeat band")
let chart=HistoryChartView();chart.points=points
check(chart.toolTip?.contains("推断")==true,"inference disclosed")
feed(store,reading(13000,0,account:"b"));feed(store,reading(24000,100))
check(store.points.last!.event?.showsReset != true,"switch back to account does not infer reset")
struct Archive:Codable {let version:Int;let points:[HistoryPoint]}
let file=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("legacy.json")
let old=[HistoryPoint(reading:reading(0,0),gapBefore:false,event:nil),HistoryPoint(reading:reading(10800,100),gapBefore:true,event:HistoryResetClassifier.classify(previous:reading(0,0),current:reading(10800,100)),gapReason:"read-unavailable")]
let data=try JSONEncoder().encode(Archive(version:1,points:old));try data.write(to:file)
let replay=QuotaHistoryStore(file:file,now:base.addingTimeInterval(10800));feed(replay,reading(10800,100))
check(replay.visiblePoints(series:reading(0,0).series).last!.event?.showsReset==true,"legacy unknown event replay upgraded")
let replayData=try Data(contentsOf:file)
check(replayData==data,"replay leaves archive unchanged")
check(replay.points.map{$0.reading.remaining}==[0,100],"no invented gap values")
check(HistoryResetClassifier.classify(previous:reading(0,0),current:reading(10800,99),gap:true)?.showsReset==false,"partial recovery remains unknown correction")
check(HistoryResetClassifier.classify(previous:reading(0,0),current:reading(10800,100,account:"b"),gap:true)==nil,"different accounts never compare")
print("PASS full recovery detection, one marker/band, inferred tooltip, legacy replay without mutation, repeated 100%, account isolation and partial recovery")
