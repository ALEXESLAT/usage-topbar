import AppKit
func check(_ test: @autoclosure () -> Bool, _ text: String) { precondition(test(),text) }
let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
let output=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let now=Date(), end=now.timeIntervalSince1970
let temp=URL(fileURLWithPath:CommandLine.arguments[2]).appendingPathComponent("fixture.json")
var samples:[HistoryPoint]=[]
for i in 0...576 {
 let t=end-12*86400+Double(i)*1800
 let phase=i % 240
 if (490...504).contains(i) { continue }
 let value=i>=505 ? max(0,100-Double(i-505)*0.35) : max(0,100-Double(phase)*0.35)
 let reading=HistoryReading(account:"fixture",series:"codex/secondary/10080.0",time:t,remaining:value,resetsAt:t+604800,duration:604800,cards:[],availableCards:0)
 var event:HistoryReset?
 if i>0 && i%240==0 { event=HistoryReset(kind:.cycle,lowerBound:t-30,upperBound:t,exactTime:t,inferred:true,source:"fixture") }
 if i==505 { event=HistoryReset(kind:.special,lowerBound:t-16*1800,upperBound:t,exactTime:nil,inferred:true,source:"fixture") }
 samples.append(HistoryPoint(reading:reading,gapBefore:i==505,event:event))
}
struct Fixture:Codable { let version:Int; let points:[HistoryPoint] }
try JSONEncoder().encode(Fixture(version:1,points:samples)).write(to:temp)
let store=QuotaHistoryStore(file:temp,now:now)
store.receive([samples.last!.reading],now:now)
for expanded in [false,true] {
 for dark in [false,true] {
  let content=HistoryPanelContent(store:store,expanded:expanded)
  let window=NSWindow(contentRect:content.bounds,styleMask:.borderless,backing:.buffered,defer:false)
  window.contentView=content;window.appearance=NSAppearance(named:dark ? .darkAqua:.aqua)
  content.needsLayout=true;content.layoutSubtreeIfNeeded()
  check(content.chart.bounds.width>=content.scroll.bounds.width,"chart fills viewport")
  check(content.seriesButton.isHidden,"single quota selector is redundant")
  if expanded {
   let screenSpan = content.scroll.bounds.width / content.chart.bounds.width * (content.chart.end-content.chart.start)
   check(abs(screenSpan-7*86400)<1,"expanded viewport is seven days, not total retention")
   check(content.chart.end-content.chart.start>7*86400,"older retained history remains scrollable")
  } else {
   check(abs(content.chart.end-content.chart.start-4*86400)<1,"thumbnail is exactly four days")
   var opened=false;content.chart.onOpen={opened=true}
   let click=NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
   content.chart.mouseDown(with:click);check(opened,"thumbnail click dispatches history opening")
  }
  if expanded {
   let before=content.scroll.contentView.bounds.minX
   check(before>0,"opens at now")
   content.scroll.contentView.scroll(to:CGPoint(x:0,y:0));content.scroll.reflectScrolledClipView(content.scroll.contentView)
   check(content.scroll.contentView.bounds.minX==0,"scroll reaches oldest")
   content.nowButton.performClick(nil)
   check(content.scroll.contentView.bounds.minX>0,"return now")
   let cg=CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:2,wheel1:0,wheel2:100,wheel3:0)!
   content.scroll.scrollWheel(with:NSEvent(cgEvent:cg)!)
   check(content.scroll.contentView.bounds.minX<=before+2,"horizontal gesture is bounded")
   content.nowButton.performClick(nil)
  }
  let a=CGPoint(x:0,y:0), b=CGPoint(x:100,y:100), (c1,c2)=HistoryChartGeometry.controls(from:a,to:b)
  for step in 0...100 {
   let t=Double(step)/100, u=1-t
   let y=u*u*u*a.y+3*u*u*t*c1.y+3*u*t*t*c2.y+t*t*t*b.y
   check((0...100).contains(y),"smooth curve cannot overshoot")
  }
  guard let rep=content.bitmapImageRepForCachingDisplay(in:content.bounds) else { fatalError("bitmap") }
  content.cacheDisplay(in:content.bounds,to:rep)
  let name="history-\(expanded ? "7day":"4day")-\(dark ? "dark":"light").png"
  try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name))
 }
}
print("PASS chart: bounded interpolation, 4/7 day layouts, history scrolling, return-now, synthetic horizontal event; four fixture previews (not real compositor/physical trackpad acceptance)")

// Segment boundaries, isolated evidence and monotone controls at irregular intervals.
for i in 1..<samples.count {
    let connected = HistoryChartGeometry.connects(samples, at:i)
    check(connected == (samples[i].event == nil && samples[i].reading.time-samples[i-1].reading.time < 7200), "never bridge gap/reset")
}
check(HistoryChartGeometry.isolated([samples[0]], at:0), "single observation stays a point")
check(!HistoryChartGeometry.isolated(Array(samples[0...2]), at:1), "continuous samples have no permanent dots")
for ys in [[100.0,80,70,0], [0,30,80,100], [50,50,50,50], [0,90,10,100], [0,100,100,0]] {
 let a=CGPoint(x:1,y:ys[1]),b=CGPoint(x:10,y:ys[2])
 let (c1,c2)=HistoryChartGeometry.controls(from:a,to:b,previous:CGPoint(x:0,y:ys[0]),next:CGPoint(x:100,y:ys[3]))
 for step in 0...1000 {
  let t=Double(step)/1000,u=1-t,y=u*u*u*a.y+3*u*u*t*c1.y+3*u*t*t*c2.y+t*t*t*b.y
  check(y>=min(a.y,b.y)-1e-9 && y<=max(a.y,b.y)+1e-9,"irregular/turning/flat curve cannot overshoot")
 }
}
// Sparse startup fixture: do not stretch eight hours into four days of invented history.
var sparse:[HistoryPoint]=[]
for i in 0...20 {
 let t=end-8.7*3600+Double(i)*8.7*3600/20
 let value=85-Double(i)*2
 let r=HistoryReading(account:"sparse",series:"codex/secondary/10080.0",time:t,remaining:value,resetsAt:t+604800,duration:604800,cards:[],availableCards:0)
 sparse.append(HistoryPoint(reading:r,gapBefore:[0,5,10,15].contains(i),event:nil))
}
try JSONEncoder().encode(Fixture(version:1,points:sparse)).write(to:temp)
let sparseStore=QuotaHistoryStore(file:temp,now:now);sparseStore.receive([sparse.last!.reading],now:now)
let sparseView=HistoryPanelContent(store:sparseStore,expanded:false)
let sparseWindow=NSWindow(contentRect:sparseView.bounds,styleMask:.borderless,backing:.buffered,defer:false)
sparseWindow.contentView=sparseView;sparseWindow.appearance=NSAppearance(named:.darkAqua)
sparseView.needsLayout=true;sparseView.layoutSubtreeIfNeeded()
let sparseBitmap=sparseView.bitmapImageRepForCachingDisplay(in:sparseView.bounds)!
sparseView.cacheDisplay(in:sparseView.bounds,to:sparseBitmap)
try sparseBitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("history-sparse-4day-dark.png"))
let extra=HistoryReading(account:"sparse",series:"codex/primary/300.0",time:end,remaining:70,resetsAt:end+18000,duration:18000,cards:[],availableCards:0)
sparseStore.receive([sparse.last!.reading,extra],now:now);sparseView.refresh()
check(!sparseView.seriesButton.isHidden && sparseView.seriesButton.numberOfItems==2,"retain actual multi-quota switching")
print("PASS marker removal, single/multiple quota selector, sparse 8.7-hour fixture, gap/reset boundaries and irregular monotone interpolation")

let cornerPoints=[CGPoint(x:0,y:0),CGPoint(x:10,y:100),CGPoint(x:20,y:0)]
let rounded=HistoryChartGeometry.roundedPath(cornerPoints)
var moves=0, curves=0, vertices=Array(repeating:CGPoint.zero,count:3)
for i in 0..<rounded.elementCount {
 let element=vertices.withUnsafeMutableBufferPointer { rounded.element(at:i,associatedPoints:$0.baseAddress!) }
 if element == .moveTo { moves+=1 }
 if element == .curveTo {
  curves+=1
  check(vertices.allSatisfy{(0...100).contains($0.y)},"rounded controls inside observed bounds")
  check(abs(vertices[2].x-15)<1e-9 && abs(vertices[2].y-50)<1e-9,"50 percent is edge trim, not quota allowance")
 }
}
check(moves==1 && curves==1,"one joined path per run")
check(HistoryChartGeometry.runs(samples).flatMap{$0} == Array(samples.indices),"each real sample belongs to exactly one run")
for run in HistoryChartGeometry.runs(samples) {
 for index in run.dropFirst() { check(samples[index].event==nil && samples[index].reading.time-samples[index-1].reading.time<7200,"no smoothing across real gaps or resets") }
}
print("PASS single continuous path, 50 percent corner geometry, bounded controls and complete segment membership")

check(rounded.lineWidth==6,"exactly double the original 3pt stroke")
let template=samples[0].reading
func gapPair(_ seconds:Double, reason:String?=nil, account:String?=nil, series:String?=nil, reset:Bool=false)->[HistoryPoint] {
 let b=HistoryReading(account:account ?? template.account,series:series ?? template.series,time:template.time+seconds,remaining:40,resetsAt:template.resetsAt,duration:template.duration,cards:[],availableCards:0)
 let event=reset ? HistoryReset(kind:.cycle,lowerBound:template.time,upperBound:b.time,exactTime:nil,inferred:true,source:"fixture"):nil
 return [HistoryPoint(reading:template,gapBefore:true,event:nil),HistoryPoint(reading:b,gapBefore:true,event:event,gapReason:reason)]
}
for seconds in [30.0,90,1800,1830,3600,7199] { check(HistoryChartGeometry.connects(gapPair(seconds),at:1),"short gaps connect as trends") }
for seconds in [7200.0,7201,14400] {
 let p=gapPair(seconds)
 check(!HistoryChartGeometry.connects(p,at:1) && HistoryChartGeometry.isLongGap(p,at:1),"two hour inclusive boundary is dashed")
}
for p in [gapPair(30,account:"other"),gapPair(30,series:"other"),gapPair(30,reason:"account-change"),gapPair(30,reset:true)] {
 check(!HistoryChartGeometry.connects(p,at:1),"never bridge reset/account/period boundaries")
}
let (gapStart,gapEnd)=HistoryChartGeometry.gapMarker(from:CGPoint(x:10,y:40),to:CGPoint(x:30,y:90))
check(gapStart.y==40 && gapEnd.y==40 && gapEnd.x==30,"long gap stays at last known value even when recovery differs")
print("PASS 6pt/50 percent, short gaps and missed sample, 2h boundary, long offline horizontal dash, reset/account/period separation")

let densePlateau=(0...60).map { CGPoint(x:Double($0),y:0) } + [CGPoint(x:61,y:10),CGPoint(x:62,y:20)]
let savedDense=densePlateau
let simplified=HistoryChartGeometry.visualPoints(densePlateau)
check(simplified.count==3 && simplified.first==densePlateau.first && simplified.last==densePlateau.last,"collapse dense collinear vertices without moving endpoints")
check(densePlateau==savedDense,"raw screen coordinates remain untouched")
let broad=HistoryChartGeometry.roundedPath(densePlateau)
var broadVertices=Array(repeating:CGPoint.zero,count:3)
let entryType=broadVertices.withUnsafeMutableBufferPointer { broad.element(at:1,associatedPoints:$0.baseAddress!) }
check(entryType == .lineTo && abs(broadVertices[0].x-30)<1e-9,"round across the long visual plateau, not a subpixel neighbor")
let flat=HistoryChartGeometry.visualPoints([CGPoint(x:0,y:50),CGPoint(x:1,y:50),CGPoint(x:2,y:50)])
check(flat.count==2,"constant quota stays exactly horizontal")
print("PASS 50 percent visual simplification (3.0pt), broad rounded plateau, original input/endpoints preserved")

#if USAGE_TOPBAR_TESTING
let simulation = SimulatedHistorySource(now:now)
let persistedBefore = try Data(contentsOf:temp)
for expanded in [false,true] {
 let content=HistoryPanelContent(store:simulation,expanded:expanded)
 let window=NSWindow(contentRect:content.bounds,styleMask:.borderless,backing:.buffered,defer:false)
 window.contentView=content; window.appearance=NSAppearance(named:.darkAqua)
 content.needsLayout=true;content.layoutSubtreeIfNeeded()
 check(content.message.stringValue=="模拟数据","simulation disclosure")
 let span=content.scroll.bounds.width/content.chart.bounds.width*(content.chart.end-content.chart.start)
 check(abs(span-(expanded ? 7:4)*86400)<1,"simulation keeps fixed viewport")
 let actual=simulation.visiblePoints(series:simulation.series()[0])
 check(content.chart.points==actual,"chart uses fixture without changing samples")
 for i in 1..<actual.count where actual[i].gapBefore {
  let dt=actual[i].reading.time-actual[i-1].reading.time
  check(HistoryChartGeometry.connects(actual,at:i)==(dt<7200),"fixture short/long gap policy")
 }
 let rep=content.bitmapImageRepForCachingDisplay(in:content.bounds)!
 content.cacheDisplay(in:content.bounds,to:rep)
 try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("simulation-\(expanded ? "7day":"4day").png"))
 if expanded {
  content.scroll.contentView.scroll(to:.zero);content.scroll.reflectScrolledClipView(content.scroll.contentView)
  check(content.scroll.contentView.bounds.minX==0,"simulation older history scroll")
  content.cacheDisplay(in:content.bounds,to:rep)
  try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("simulation-older.png"))
 }
}
let persistedAfter = try Data(contentsOf:temp)
check(persistedBefore==persistedAfter,"simulation presentation never modifies real history")
print("PASS simulated source 4/7 days, older scrolling, label, missing-sample policy and unchanged persisted history")
#endif

let tickStart=Date(timeIntervalSince1970:1800000000).timeIntervalSince1970-14*86400
let ticks0=HistoryChartGeometry.dateTicks(start:tickStart,end:tickStart+14*86400,documentWidth:1532,offset:0)
for offset in stride(from:-40.0,through:840.0,by:4.5) {
 let ticks=HistoryChartGeometry.dateTicks(start:tickStart,end:tickStart+14*86400,documentWidth:1532,offset:offset)
 check(Set(ticks.map { $0.time }).count==ticks.count,"unique stable date identities during scroll and overscroll")
 for (a,b) in zip(ticks0,ticks) { check(a.time==b.time && abs(a.x-b.x-offset)<1e-8,"date moves only with offset, never sticks to viewport edge") }
}
let rising=HistoryPoint(reading:HistoryReading(account:template.account,series:template.series,time:template.time+30,remaining:100,resetsAt:nil,duration:template.duration,cards:nil,availableCards:nil),gapBefore:false,event:HistoryReset(kind:.cycle,lowerBound:template.time,upperBound:template.time+30,exactTime:nil,inferred:true,source:"fixture"))
let pair=[HistoryPoint(reading:HistoryReading(account:template.account,series:template.series,time:template.time,remaining:10,resetsAt:nil,duration:template.duration,cards:nil,availableCards:nil),gapBefore:false,event:nil),rising]
let connector=HistoryChartGeometry.resetConnector(pair,at:1,from:CGPoint(x:0,y:90),to:CGPoint(x:10,y:0))!
check(connector.0.x==10 && connector.1.x==10 && connector.0.y==90 && connector.1.y==0,"reset connector is vertical at observed sample, spans only observed heights")
check(HistoryChartGeometry.resetConnector(gapPair(7200),at:1,from:.zero,to:CGPoint(x:10,y:90))==nil,"ordinary gap has no reset connector/band")
var switched=pair;switched[1].gapReason="account-change"
check(HistoryChartGeometry.resetConnector(switched,at:1,from:.zero,to:CGPoint(x:10,y:90))==nil,"account change has no reset decoration")
let bands=HistoryChartGeometry.resetBands(connectors:[10,20,80].map { (CGPoint(x:$0,y:70),CGPoint(x:$0,y:120)) },plot:CGRect(x:0,y:46,width:100,height:100),viewportWidth:24/0.045)
check(bands.count==2 && bands[0].minX==0 && bands[0].maxX==32,"nearby bands merged and clipped")
check(bands.allSatisfy { $0.minY==70 && $0.maxY==120 },"bands span observed values only, not entire plot")
check(HistoryChartGeometry.plotTop-22>=8,"marker band has safe clearance from 100 percent line")
print("PASS stable dates across scroll/overscroll, reset-only vertical connector, merged clipped bands and marker clearance")

let ratioBands=HistoryChartGeometry.resetBands(connectors:[(CGPoint(x:100,y:60),CGPoint(x:100,y:120))],plot:CGRect(x:0,y:46,width:750,height:100),viewportWidth:750)
check(abs(ratioBands[0].width/750-0.045)<1e-9,"reference band occupies 4.5 percent of viewport plot")
#if USAGE_TOPBAR_TESTING
let hoverContent=HistoryPanelContent(store:SimulatedHistorySource(now:now),expanded:true)
let hoverWindow=NSWindow(contentRect:hoverContent.bounds,styleMask:.borderless,backing:.buffered,defer:false)
hoverWindow.contentView=hoverContent;hoverWindow.appearance=NSAppearance(named:.darkAqua)
hoverContent.layoutSubtreeIfNeeded()
let hoverChart=hoverContent.chart
let ps=hoverChart.points
let visibleIndex=ps.indices.first { i in i>0 && hoverChart.point(ps[i]).x>hoverContent.scroll.contentView.bounds.minX+60 && HistoryChartGeometry.connects(ps,at:i) }!
let left=hoverChart.point(ps[visibleIndex-1]),right=hoverChart.point(ps[visibleIndex])
let x=(left.x+right.x)/2
hoverChart.updateCrosshair(at:CGPoint(x:x,y:100))
check(hoverChart.crosshairValue != nil && hoverChart.crosshairText.hasSuffix("%") && !hoverChart.crosshairText.contains(" ") && !hoverChart.crosshairText.contains("\n"),"detail hover is percentage only, no time or extra detail")
let rebuilds=hoverChart.geometryBuildCount
for i in 0..<100 { hoverChart.updateCrosshair(at:CGPoint(x:x+Double(i)/1000,y:100)) }
check(hoverChart.geometryBuildCount==rebuilds,"hover does not rebuild full history")
let gap=ps.indices.first { HistoryChartGeometry.isLongGap(ps,at:$0) }!
hoverChart.updateCrosshair(at:CGPoint(x:(hoverChart.point(ps[gap-1]).x+hoverChart.point(ps[gap]).x)/2,y:100))
check(hoverChart.crosshairValue==nil && hoverChart.crosshairText.isEmpty,"no interpolation across missing data")
let reset=ps.indices.first { ps[$0].event != nil }!
hoverChart.updateCrosshair(at:CGPoint(x:(hoverChart.point(ps[reset-1]).x+hoverChart.point(ps[reset]).x)/2,y:100))
check(hoverChart.crosshairValue==nil,"no intermediate quota along reset jump")
hoverChart.updateCrosshair(at:hoverChart.point(ps[reset]))
check(abs(hoverChart.crosshairValue!-100)<0.01,"reset observation keeps post-reset curve endpoint")
hoverChart.updateCrosshair(at:CGPoint(x:x,y:100))
hoverContent.scroll.contentView.scroll(to:CGPoint(x:0,y:0));hoverContent.scroll.reflectScrolledClipView(hoverContent.scroll.contentView)
check(hoverChart.crosshairText.isEmpty,"scroll clears hover")
hoverChart.updateCrosshair(at:CGPoint(x:x,y:0));check(hoverChart.crosshairText.isEmpty,"outside plot hides hover")
let path=HistoryChartGeometry.roundedPath([CGPoint(x:0,y:0),CGPoint(x:10,y:100),CGPoint(x:20,y:0)])
let segments=HistoryChartGeometry.curveSegments(path)
check(HistoryChartGeometry.curveY(segments,at:10)!<100,"crosshair follows rounded visible curve, not raw corner")
print("PASS detail crosshair cache, visible curve evaluation, percentage-only display, gap/reset safety, scroll/exit hiding and proportional bands")
#endif
#if USAGE_TOPBAR_TESTING
let appendChart=HistoryChartView(frame:CGRect(x:0,y:0,width:760,height:280))
appendChart.showsCrosshair=true;appendChart.start=end-86400;appendChart.end=end+86400
var appendPoints:[HistoryPoint]=[]
for i in 0..<40 {
 let reading=HistoryReading(account:"append",series:"codex/secondary/10080.0",time:end-20*3600+Double(i)*1800,remaining:100-Double(i)*1.1,resetsAt:nil,duration:604800,cards:nil,availableCards:nil)
 appendPoints.append(HistoryPoint(reading:reading,gapBefore:false,event:nil))
}
appendChart.points=appendPoints
appendChart.updateCrosshair(at:CGPoint(x:200,y:100))
let originalShape=appendChart.fittedCurveForTesting,originalFitCount=appendChart.fullFitCount
let oldQuota=appendPoints.map { $0.reading.remaining }
let begin=ProcessInfo.processInfo.systemUptime
for i in 40..<70 {
 let reading=HistoryReading(account:"append",series:"codex/secondary/10080.0",time:end-20*3600+Double(i)*1800,remaining:100-Double(i)*1.1,resetsAt:nil,duration:604800,cards:nil,availableCards:nil)
 appendPoints.append(HistoryPoint(reading:reading,gapBefore:false,event:nil));appendChart.points=appendPoints
 appendChart.updateCrosshair(at:CGPoint(x:200,y:100))
 check(appendChart.lastRefitStartTime==appendPoints[i-8].reading.time,"only last eight intervals refitted")
 let shape=appendChart.fittedCurveForTesting
 let early=end-18*3600
 check(abs(HistoryChartGeometry.curveY(shape,at:early)!-HistoryChartGeometry.curveY(originalShape,at:early)!)<1e-8,"distant historical shape remains stable")
 check(shape.allSatisfy { [$0.a.y,$0.b.y,$0.c1?.y ?? $0.a.y,$0.c2?.y ?? $0.b.y].allSatisfy { $0 >= -1e-8 && $0 <= 100+1e-8 } },"incremental controls bounded 0 to 100")
}
check(appendChart.fullFitCount==originalFitCount && appendChart.tailFitCount==30,"thirty appends use local refits without full fitting")
check(Array(appendPoints.prefix(40)).map { $0.reading.remaining }==oldQuota,"original quotas unchanged")
let elapsed=ProcessInfo.processInfo.systemUptime-begin
let resetReading=HistoryReading(account:"append",series:"codex/secondary/10080.0",time:appendPoints.last!.reading.time+1800,remaining:100,resetsAt:nil,duration:604800,cards:nil,availableCards:nil)
appendPoints.append(HistoryPoint(reading:resetReading,gapBefore:false,event:HistoryReset(kind:.cycle,lowerBound:resetReading.time-1800,upperBound:resetReading.time,exactTime:nil,inferred:true,source:"fixture")))
let beforeReset=appendChart.fittedCurveForTesting
appendChart.points=appendPoints;appendChart.updateCrosshair(at:CGPoint(x:200,y:100))
check(appendChart.tailFitCount==30,"reset boundary does not refit preceding run")
check(HistoryChartGeometry.curveY(appendChart.fittedCurveForTesting,at:resetReading.time-900)==nil,"reset gap never filled by tail fitting")
check(appendChart.fittedCurveForTesting.count==beforeReset.count,"old run kept on reset append")
print("PASS 50 percent local fitting: 30 appends, 8 intervals each, stable distant history, unchanged samples, bounded controls and reset boundary; seconds=\(elapsed)")
#endif
#if USAGE_TOPBAR_TESTING
let labelsContent=HistoryPanelContent(store:SimulatedHistorySource(now:now),expanded:true)
let labelsWindow=NSWindow(contentRect:labelsContent.bounds,styleMask:.borderless,backing:.buffered,defer:false)
labelsWindow.contentView=labelsContent;labelsWindow.appearance=NSAppearance(named:.darkAqua);labelsContent.layoutSubtreeIfNeeded()
let lc=labelsContent.chart
let lp=lc.points
let vi=lp.indices.first { i in i>0 && lc.point(lp[i]).x>labelsContent.scroll.contentView.bounds.minX+100 && HistoryChartGeometry.connects(lp,at:i) }!
lc.updateCrosshair(at:CGPoint(x:lc.point(lp[vi]).x,y:100))
let readouts=labelsContent.hoverLabels.readouts
check(Set(readouts.map { $0.kind })==Set(["axis","point","time"]),"three separate readouts")
check(readouts.filter { $0.kind != "time" }.allSatisfy { $0.text==lc.crosshairText },"axis and point percentage agree with visible curve")
check(readouts.first { $0.kind=="time" }!.text.contains(":"),"bottom readout includes current coordinate time")
check(readouts.first { $0.kind=="axis" }!.rect.maxX<labelsContent.scroll.frame.minX,"left value stays in axis gutter")
check(readouts.first { $0.kind=="axis" }!.rect.minX>4,"axis percentage shifts right without growing gutter")
for a in readouts.indices {
 check(labelsContent.hoverLabels.bounds.contains(readouts[a].rect),"readout not clipped")
 for b in readouts.indices where b>a { check(!readouts[a].rect.intersects(readouts[b].rect),"readouts never overlap") }
}
let hoverBitmap=labelsContent.bitmapImageRepForCachingDisplay(in:labelsContent.bounds)!
labelsContent.cacheDisplay(in:labelsContent.bounds,to:hoverBitmap)
try hoverBitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("three-readouts.png"))
let visibleGap=lp.indices.first { i in i>0 && lc.point(lp[i]).x>labelsContent.scroll.contentView.bounds.minX && HistoryChartGeometry.isLongGap(lp,at:i) }!
lc.updateCrosshair(at:CGPoint(x:(lc.point(lp[visibleGap-1]).x+lc.point(lp[visibleGap]).x)/2,y:100))
check(labelsContent.hoverLabels.readouts.map { $0.kind }==["time"],"missing interval has time only, no fabricated percentages")
lc.clearCrosshair();check(labelsContent.hoverLabels.readouts.isEmpty,"exit clears all three readouts")
print("PASS three readouts: axis gutter, point percentage, coordinate date/time, no overlap/clipping, missing value and exit")
#endif

#if USAGE_TOPBAR_TESTING
let compactLabels=HistoryPanelContent(store:SimulatedHistorySource(now:now),expanded:false)
let compactWindow=NSWindow(contentRect:compactLabels.bounds,styleMask:.borderless,backing:.buffered,defer:false)
compactWindow.contentView=compactLabels;compactLabels.layoutSubtreeIfNeeded()
let cc=compactLabels.chart
check(abs(cc.end-cc.start-4*86400)<0.01,"compact retains four days")
for x in stride(from:CGFloat(9),through:cc.bounds.width-9,by:3) {
 cc.updateCrosshair(at:CGPoint(x:x,y:80))
 let labels=compactLabels.hoverLabels.readouts
 check(labels.count<=2 && labels.filter { $0.kind=="time" }.count==1 && !labels.contains { $0.kind=="axis" },"compact time and single percentage")
 for label in labels { check(compactLabels.hoverLabels.bounds.contains(label.rect),"compact edge label stays inside") }
 if cc.crosshairValue==nil { check(labels.count==1 && labels[0].kind=="time","compact gap retains only time") }
}
cc.clearCrosshair();check(compactLabels.hoverLabels.readouts.isEmpty,"compact exit clears label")
print("PASS compact four-day time plus single percentage, edge bounds, missing values and exit")
#endif

compactLabels.chart.updateTrackingAreas()
check(compactLabels.chart.trackingAreas.contains { $0.options.contains(.activeInActiveApp) },"popover hover remains active when detail owns key window")

let varied=HistoryChartGeometry.resetBands(connectors:[(CGPoint(x:20,y:60),CGPoint(x:20,y:100)),(CGPoint(x:30,y:80),CGPoint(x:30,y:120))],plot:CGRect(x:0,y:46,width:100,height:100),viewportWidth:24/0.045)
check(!varied.contains { $0.contains(CGPoint(x:9,y:110)) },"merging cannot invent lower portion of earlier band")
check(varied.contains { $0.contains(CGPoint(x:30,y:110)) },"later band keeps observed lower portion")
for i in varied.indices { for j in varied.indices where j>i { check(!varied[i].intersects(varied[j]),"merged band regions never double opacity") } }
check(HistoryChartGeometry.resetConnector([rising],at:0,from:.zero,to:CGPoint(x:10,y:0))==nil,"missing prior value has no invented reset band")
print("PASS reset bands: observed-height extent, exact nonoverlapping union and missing prior value")

let roundedBand=HistoryChartGeometry.resetBandOutline(connectors:[(CGPoint(x:50,y:70),CGPoint(x:50,y:120))],plot:CGRect(x:0,y:46,width:100,height:100),viewportWidth:24/0.045,compact:false)
check(roundedBand.boundingBoxOfPath.minY==70 && roundedBand.boundingBoxOfPath.maxY==120,"rounded band preserves exact observed bounds")
check(!roundedBand.contains(CGPoint(x:38.2,y:70.2)) && roundedBand.contains(CGPoint(x:50,y:71)),"rounded corners without capsule ends")
let shortBand=HistoryChartGeometry.resetBandOutline(connectors:[(CGPoint(x:50,y:70),CGPoint(x:50,y:72))],plot:CGRect(x:0,y:46,width:100,height:100),viewportWidth:24/0.045,compact:true)
check(shortBand.boundingBoxOfPath.minY==70 && shortBand.boundingBoxOfPath.maxY==72,"short rounded band does not extend bounds")
print("PASS reset band 5pt detail / 3pt compact corners with short-height clamp")

for (month,day,expectedGap) in [(3,7,11.0),(10,31,13.0)] {
 var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"America/New_York")!
 let begin=calendar.date(from:DateComponents(year:2026,month:month,day:day))!
 let finish=calendar.date(byAdding:.day,value:3,to:begin)!
 let grid=HistoryChartGeometry.halfDayTicks(start:begin.timeIntervalSince1970,end:finish.timeIntervalSince1970,calendar:calendar)
 check(grid.count==7 && Set(grid).count==7,"no duplicate midnight at DST boundary")
 check(grid.allSatisfy { [0,12].contains(calendar.component(.hour,from:Date(timeIntervalSince1970:$0))) },"grid remains local noon and midnight")
 check(zip(grid,grid.dropFirst()).contains { abs(($0.1-$0.0)/3600-expectedGap)<0.001 },"DST grid uses calendar boundaries, not fixed 12-hour durations")
}
print("PASS local noon/midnight grid, 24:00 dedup and spring/fall DST")

check(compactLabels.chart.acceptsFirstMouse(for:nil),"compact opens on first click without key-window preactivation")

// Real raster assertions: fixed full-axis coordinates, intermediate stops and no area fill.
let axisPalette=ProgressGradientSettings(stops:[
 ProgressGradientStop(location:0,red:1,green:0,blue:0),
 ProgressGradientStop(location:0.5,red:0,green:1,blue:0),
 ProgressGradientStop(location:1,red:0,green:0,blue:1)])
func gradientRaster(_ offset:CGFloat,cached:Bool=false) -> NSBitmapImageRep {
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:180,pixelsHigh:120,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
 let ctx=NSGraphicsContext.current!.cgContext;ctx.translateBy(x:0,y:120);ctx.scaleBy(x:1,y:-1)
 let p=NSBezierPath();p.lineWidth=6
 for y in [10.0,60,110] { p.move(to:CGPoint(x:20+offset,y:y));p.line(to:CGPoint(x:130+offset,y:y)) }
 if cached { HistoryCurvePaint.draw(mask:HistoryCurvePaint.strokeMask(p),plot:CGRect(x:10,y:10,width:150,height:100),gradient:HistoryCurvePaint.gradient(axisPalette)) }
 else { HistoryCurvePaint.draw(p,plot:CGRect(x:10,y:10,width:150,height:100),settings:axisPalette) }
 NSGraphicsContext.restoreGraphicsState();return bitmap
}
let raster=gradientRaster(0),shiftedRaster=gradientRaster(12)
func rgba(_ bitmap:NSBitmapImageRep,_ x:Int,_ y:Int)->[CGFloat] {
 let c=bitmap.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!
 return [c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent]
}
let top=rgba(raster,70,10),middle=rgba(raster,70,60),bottom=rgba(raster,70,110)
check(top[2]>0.97 && bottom[0]>0.97,"top 100 is right endpoint, bottom 0 is left endpoint")
check(middle[1]>0.97,"middle stop preserved")
check([top,middle,bottom].allSatisfy{$0[3]>0.99},"no quota-dependent alpha fade")
for y in [10,60,110] { check(zip(rgba(raster,70,y),rgba(shiftedRaster,90,y)).allSatisfy{abs($0-$1)<0.01},"horizontal translation preserves quota color") }
check(rgba(raster,70,35)[3]==0,"no area fill or bridge between separate paths")
try raster.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("fixed-axis-gradient.png"))
print("PASS vertical gradient raster: endpoint direction, intermediate stop, fixed-axis translation, opaque low quota, no area or gap fill")
for expanded in [false,true] { for dark in [false,true] {
 let content=HistoryPanelContent(store:SimulatedHistorySource(now:now),expanded:expanded)
 content.chart.curveGradient=axisPalette
 let window=NSWindow(contentRect:content.bounds,styleMask:.borderless,backing:.buffered,defer:false)
 window.contentView=content;window.appearance=NSAppearance(named:dark ? .darkAqua:.aqua)
 content.layoutSubtreeIfNeeded()
 let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds)!
 content.cacheDisplay(in:content.bounds,to:bitmap)
 try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("gradient-\(expanded ? "7day":"4day")-\(dark ? "dark":"light").png"))
}}

check(raster.representation(using:.png,properties:[:])==gradientRaster(0,cached:true).representation(using:.png,properties:[:]),"cached gradient paint is pixel-identical")
print("PASS cached stroke/gradient preserves raster pixels")

// A retained, closed view catches up when opened without doing hidden chart work.
let hiddenStore=QuotaHistoryStore(file:nil,now:now)
let hiddenContent=HistoryPanelContent(store:hiddenStore,expanded:true)
let hiddenWindow=NSWindow(contentRect:hiddenContent.bounds,styleMask:.borderless,backing:.buffered,defer:false)
hiddenWindow.contentView=hiddenContent
let hiddenInitial=hiddenContent.chart.points
let hiddenReading=HistoryReading(account:"hidden-fixture",series:"codex/primary/10080.0",time:now.timeIntervalSince1970,remaining:42,resetsAt:now.timeIntervalSince1970+604800,duration:604800,cards:[],availableCards:0)
hiddenStore.receive([hiddenReading],now:now)
hiddenContent.refreshIfVisible()
check(hiddenContent.chart.points==hiddenInitial,"hidden window does not refresh chart")
hiddenContent.refresh()
check(hiddenContent.chart.points==hiddenStore.visiblePoints(series:hiddenReading.series),"opening refresh catches up to latest data")
print("PASS retained hidden chart skips refresh and catches up on explicit presentation refresh")
