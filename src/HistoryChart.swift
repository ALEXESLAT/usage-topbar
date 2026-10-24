import AppKit

/// Bounded Bézier controls: the curve cannot leave the two observed values.
enum HistoryChartGeometry {
    static func controls(from a: CGPoint, to b: CGPoint, previous: CGPoint? = nil, next: CGPoint? = nil) -> (CGPoint, CGPoint) {
        let dx = b.x - a.x
        guard dx > 0 else { return (a, b) }
        let slope = (b.y - a.y) / dx
        func tangent(_ neighbor: CGFloat?) -> CGFloat {
            guard let neighbor else { return slope }
            guard slope * neighbor > 0 else { return 0 }
            // Harmonic mean keeps monotone runs smooth; clamp handles irregular spacing.
            return copysign(min(abs(2 * slope * neighbor / (slope + neighbor)), 3 * abs(slope)), slope)
        }
        let before = previous.flatMap { a.x > $0.x ? (a.y - $0.y) / (a.x - $0.x) : nil }
        let after = next.flatMap { $0.x > b.x ? ($0.y - b.y) / ($0.x - b.x) : nil }
        return (CGPoint(x: a.x + dx/3, y: a.y + tangent(before)*dx/3),
                CGPoint(x: b.x - dx/3, y: b.y - tangent(after)*dx/3))
    }
    static let tailRefitIntervals=8
    struct CurveSegment {
        let a:CGPoint,b:CGPoint,c1:CGPoint?,c2:CGPoint?
        func mapped(_ transform:(CGPoint)->CGPoint) -> CurveSegment {
            CurveSegment(a:transform(a),b:transform(b),c1:c1.map(transform),c2:c2.map(transform))
        }
        var endSlope:CGFloat {
            let previous=c2 ?? a
            return (b.y-previous.y)/max(0.000001,b.x-previous.x)
        }
        func leftPart(endingAt x:CGFloat) -> CurveSegment {
            guard let c1,let c2 else { return CurveSegment(a:a,b:CGPoint(x:x,y:y(at:x)),c1:nil,c2:nil) }
            var low:CGFloat=0,high:CGFloat=1
            func mix(_ p:CGPoint,_ q:CGPoint,_ t:CGFloat) -> CGPoint { CGPoint(x:p.x+(q.x-p.x)*t,y:p.y+(q.y-p.y)*t) }
            for _ in 0..<40 {
                let t=(low+high)/2
                let p=mix(a,c1,t),q=mix(c1,c2,t),r=mix(c2,b,t)
                let value=mix(mix(p,q,t),mix(q,r,t),t)
                if value.x<x { low=t } else { high=t }
            }
            let t=(low+high)/2,p=mix(a,c1,t),q=mix(c1,c2,t),r=mix(c2,b,t),v=mix(p,q,t)
            let tip=mix(v,mix(q,r,t),t)
            return CurveSegment(a:a,b:CGPoint(x:x,y:tip.y),c1:p,c2:v)
        }
        func y(at x:CGFloat) -> CGFloat {
            guard let c1,let c2 else { return a.y+(b.y-a.y)*(x-a.x)/max(0.000001,b.x-a.x) }
            func component(_ t:CGFloat,_ a:CGFloat,_ c1:CGFloat,_ c2:CGFloat,_ b:CGFloat) -> CGFloat {
                let u=1-t;return u*u*u*a+3*u*u*t*c1+3*u*t*t*c2+t*t*t*b
            }
            var lower:CGFloat=0,upper:CGFloat=1
            for _ in 0..<30 {
                let mid=(lower+upper)/2
                if component(mid,a.x,c1.x,c2.x,b.x)<x { lower=mid } else { upper=mid }
            }
            return component((lower+upper)/2,a.y,c1.y,c2.y,b.y)
        }
    }
    static func curveSegments(_ path:NSBezierPath) -> [CurveSegment] {
        var result:[CurveSegment]=[],previous=CGPoint.zero,vertices=Array(repeating:CGPoint.zero,count:3)
        for i in 0..<path.elementCount {
            let element=vertices.withUnsafeMutableBufferPointer { path.element(at:i,associatedPoints:$0.baseAddress!) }
            switch element {
            case .moveTo: previous=vertices[0]
            case .lineTo:
                if vertices[0].x>previous.x { result.append(CurveSegment(a:previous,b:vertices[0],c1:nil,c2:nil)) }
                previous=vertices[0]
            case .curveTo:
                if vertices[2].x>previous.x { result.append(CurveSegment(a:previous,b:vertices[2],c1:vertices[0],c2:vertices[1])) }
                previous=vertices[2]
            default: break
            }
        }
        return result
    }
    static func curveY(_ segments:[CurveSegment],at x:CGFloat) -> CGFloat? {
        var low=0,high=segments.count
        while low<high { let mid=(low+high)/2;if segments[mid].b.x<x { low=mid+1 } else { high=mid } }
        guard low<segments.count,segments[low].a.x<=x else { return nil }
        return segments[low].y(at:x)
    }
    static let longGapThreshold: TimeInterval = 2 * 3600
    static func comparable(_ points: [HistoryPoint], at index: Int) -> Bool {
        guard index > 0, index < points.count else { return false }
        let a=points[index-1].reading, b=points[index].reading
        return a.account == b.account && a.series == b.series && b.time > a.time
            && !["account-change", "identity-unavailable", "startup-or-account-change"].contains(points[index].gapReason ?? "")
    }
    static func connects(_ points: [HistoryPoint], at index: Int, threshold: TimeInterval = longGapThreshold) -> Bool {
        guard comparable(points, at:index), points[index].event == nil else { return false }
        // A trend connection does not claim continuous observation between samples.
        return points[index].reading.time-points[index-1].reading.time < threshold
    }
    static func isLongGap(_ points: [HistoryPoint], at index: Int, threshold: TimeInterval = longGapThreshold) -> Bool {
        comparable(points,at:index) && points[index].reading.time-points[index-1].reading.time >= threshold
    }
    static func isolated(_ points: [HistoryPoint], at index: Int) -> Bool {
        !connects(points, at: index) && !connects(points, at: index + 1)
    }
    static let smoothingStrength: CGFloat = 0.50
    static let strokeWidth: CGFloat = 6
    static let plotTop: CGFloat = 30
    static let plotBottom: CGFloat = 34
    static func resetConnector(_ points: [HistoryPoint], at index: Int, from a: CGPoint, to b: CGPoint) -> (CGPoint,CGPoint)? {
        guard comparable(points,at:index), let event=points[index].event, event.showsReset,
              points[index].reading.remaining > points[index-1].reading.remaining else { return nil }
        // Position at the first observed post-reset sample, not an invented exact event time.
        return (CGPoint(x:b.x,y:a.y),b)
    }
    private static func resetBandRects(connectors:[(CGPoint,CGPoint)],plot:CGRect,viewportWidth:CGFloat) -> [CGRect] {
        let width=max(1,viewportWidth)*0.045
        let rectangles=connectors.compactMap { a,b -> CGRect? in
            guard [a.x,a.y,b.x,b.y].allSatisfy({ $0.isFinite }) else { return nil }
            let rect=CGRect(x:b.x-width/2,y:min(a.y,b.y),width:width,height:abs(a.y-b.y)).intersection(plot)
            return rect.isNull || rect.isEmpty ? nil:rect
        }
        return rectangles
    }
    static func resetBandOutline(connectors:[(CGPoint,CGPoint)],plot:CGRect,viewportWidth:CGFloat,compact:Bool) -> CGPath {
        var outline:CGPath?
        for rect in resetBandRects(connectors:connectors,plot:plot,viewportWidth:viewportWidth) {
            let radius=min(compact ? 3:5,min(rect.width,rect.height)/2)
            let path=CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil)
            outline=outline.map { $0.union(path) } ?? path
        }
        return outline ?? CGMutablePath()
    }
    static func resetBands(connectors:[(CGPoint,CGPoint)],plot:CGRect,viewportWidth:CGFloat) -> [CGRect] {
        let rectangles=resetBandRects(connectors:connectors,plot:plot,viewportWidth:viewportWidth)
        // Merge overlapping regions without extending a band below either observed value.
        // Horizontal slices form a nonoverlapping union, so opacity is applied once.
        let edges=Array(Set(rectangles.flatMap { [$0.minY,$0.maxY] })).sorted()
        var result:[CGRect]=[]
        for (top,bottom) in zip(edges,edges.dropFirst()) {
            let active=rectangles.filter { $0.minY<bottom && $0.maxY>top }.sorted { $0.minX<$1.minX }
            var slices:[CGRect]=[]
            for rect in active {
                let slice=CGRect(x:rect.minX,y:top,width:rect.width,height:bottom-top)
                if let last=slices.last,slice.minX<=last.maxX { slices[slices.count-1]=last.union(slice) }
                else { slices.append(slice) }
            }
            result.append(contentsOf:slices)
        }
        return result
    }
    static func halfDayTicks(start:Double,end:Double,calendar:Calendar = .current) -> [Double] {
        guard start.isFinite,end.isFinite,start<=end else { return [] }
        var day=calendar.startOfDay(for:Date(timeIntervalSince1970:start))
        var ticks=Set<Double>()
        while day.timeIntervalSince1970<=end {
            let noon=calendar.date(bySettingHour:12,minute:0,second:0,of:day)
            for date in [Optional(day),noon].compactMap({ $0 }) {
                let time=date.timeIntervalSince1970
                if time>=start && time<=end { ticks.insert(time) }
            }
            guard let next=calendar.date(byAdding:.day,value:1,to:day),next>day else { break }
            day=calendar.startOfDay(for:next)
        }
        return ticks.sorted()
    }
    static func dateTicks(start: Double, end: Double, documentWidth: CGFloat, offset: CGFloat) -> [(time:Double,x:CGFloat)] {
        var result:[(time:Double,x:CGFloat)]=[]
        var day=Calendar.current.startOfDay(for:Date(timeIntervalSince1970:start))
        while day.timeIntervalSince1970<=end {
            result.append((day.timeIntervalSince1970,8+(day.timeIntervalSince1970-start)/max(1,end-start)*max(1,documentWidth-16)-offset))
            day=Calendar.current.date(byAdding:.day,value:1,to:day)!
        }
        return result
    }
    static func runs(_ points: [HistoryPoint]) -> [[Int]] {
        var result: [[Int]] = []
        for index in points.indices {
            if connects(points, at: index) { result[result.count-1].append(index) }
            else { result.append([index]) }
        }
        return result
    }
    /// Display-space simplification prevents dense, nearly collinear samples from
    /// reducing corner radii below a pixel. Input/hover observations stay untouched.
    static func visualPoints(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let tolerance = strokeWidth * smoothingStrength // 3.0 screen points, not quota units.
        var keep: Set<Int> = [0, points.count-1]
        var stack = [(0, points.count-1)]
        while let (first,last) = stack.popLast() {
            guard last-first > 1 else { continue }
            let a=points[first], b=points[last], dx=b.x-a.x, dy=b.y-a.y
            let lengthSquared=dx*dx+dy*dy
            var farthest=first, maximum: CGFloat = 0
            for i in (first+1)..<last {
                let p=points[i]
                let t=lengthSquared > 0 ? max(0,min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/lengthSquared)) : 0
                let distance=hypot(p.x-a.x-t*dx,p.y-a.y-t*dy)
                if distance > maximum { maximum=distance; farthest=i }
            }
            if maximum > tolerance {
                keep.insert(farthest); stack.append((first,farthest)); stack.append((farthest,last))
            }
        }
        return keep.sorted().map { points[$0] }
    }
    /// Round 50% of each adjoining simplified edge. The quadratic control stays
    /// at its retained vertex; convex-hull geometry cannot overshoot 0–100%.
    static func roundedPath(_ rawPoints: [CGPoint]) -> NSBezierPath {
        let points = visualPoints(rawPoints)
        let path = NSBezierPath()
        path.lineCapStyle = .round; path.lineJoinStyle = .round; path.lineWidth = strokeWidth
        path.setLineDash([], count: 0, phase: 0)
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }
        if points.count > 2 {
            for i in 1..<(points.count-1) {
                let a=points[i-1], b=points[i], c=points[i+1], t=smoothingStrength
                let entry=CGPoint(x:b.x+(a.x-b.x)*t,y:b.y+(a.y-b.y)*t)
                let exit=CGPoint(x:b.x+(c.x-b.x)*t,y:b.y+(c.y-b.y)*t)
                path.line(to:entry)
                path.curve(to:exit,
                    controlPoint1:CGPoint(x:entry.x+(b.x-entry.x)*2/3,y:entry.y+(b.y-entry.y)*2/3),
                    controlPoint2:CGPoint(x:exit.x+(b.x-exit.x)*2/3,y:exit.y+(b.y-exit.y)*2/3))
            }
        }
        path.line(to:points.last!)
        return path
    }
    static func gapMarker(from a: CGPoint, to b: CGPoint) -> (CGPoint, CGPoint) {
        (a, CGPoint(x:b.x,y:a.y))
    }
    static func gapDescription(_ reason: String?) -> String {
        switch reason {
        case "startup": return "启动后的首条读数"
        case "account-change": return "账户切换"
        case "identity-unavailable": return "账户身份暂缺"
        case "startup-or-account-change": return "启动或账户切换后的首条读数"
        case "offline": return "网络中断"
        case "sleep": return "睡眠中断"
        case "missing-window": return "额度周期读数暂缺"
        case "fresh-read-gap-over-90s": return "新鲜读取间隔超过90秒"
        case "read-unavailable": return "读取不可用"
        default: return "历史未记录具体原因"
        }
    }
    static func label(_ series: String) -> String {
        let minutes = Double(series.split(separator: "/").last ?? "") ?? 0
        return minutes >= 1440 ? "\(Int(minutes / 1440)) 天额度" : "\(Int(minutes / 60)) 小时额度"
    }
}

final class HistoryChartView: NSView {
    var points: [HistoryPoint] = [] { didSet { if points != oldValue { cacheSize=nil;clearCrosshair();needsDisplay = true } } }
    var start = Date().timeIntervalSince1970 - 4 * 86400.0
    var end = Date().timeIntervalSince1970
    var now: () -> Double = { Date().timeIntervalSince1970 }
    var onOpen: (() -> Void)?
    var pulseTimes: [Double: Double] = [:]
    var viewportPlotWidth:CGFloat=0
    var showsCrosshair=false
    var showsCompactHover=false
    var curveGradient=ProgressGradientSettings.standard { didSet { if oldValue != curveGradient { cachedGradient=nil;needsDisplay=true } } }
    private(set) var crosshairText=""
    private(set) var crosshairValue:Double?
    var onCrosshairChange:(()->Void)?
    fileprivate var crosshairTime:Double?
    fileprivate var crosshairLocation:CGPoint?
    fileprivate var crosshairY:CGFloat?
    private var cacheSize:CGSize?
    private var cacheStart=0.0,cacheEnd=0.0
    private var fittedPoints:[HistoryPoint]=[]
    private var dataSegments:[HistoryChartGeometry.CurveSegment]=[]
    private var cachedStrokeMasks:[CGPath]=[]
    private var cachedGradient:CGGradient?
    private var cachedSegments:[HistoryChartGeometry.CurveSegment]=[]
    private var projected:[CGPoint]=[]
    #if USAGE_TOPBAR_TESTING
    private(set) var geometryBuildCount=0
    private(set) var fullFitCount=0
    private(set) var tailFitCount=0
    private(set) var lastRefitStartTime:Double?
    var fittedCurveForTesting:[HistoryChartGeometry.CurveSegment] { dataSegments }

    #endif
    private lazy var crosshairOverlay=HistoryCrosshairOverlay(chart:self)
    private var tracking: NSTrackingArea?
    private var pulseTimer: Timer?
    override var isFlipped: Bool { true }
    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityElement(true); setAccessibilityRole(.image); setAccessibilityLabel("剩余额度历史，纵轴 0 至 100 百分比");crosshairOverlay.frame=bounds;crosshairOverlay.autoresizingMask=[.width,.height];addSubview(crosshairOverlay) }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!); super.updateTrackingAreas()
    }
    fileprivate var topInset:CGFloat { showsCompactHover ? 26:HistoryChartGeometry.plotTop }
    fileprivate var bottomInset:CGFloat { showsCompactHover ? 26:HistoryChartGeometry.plotBottom }
    fileprivate var plot: CGRect { CGRect(x:8,y:topInset,width:max(1,bounds.width-16),height:max(1,bounds.height-topInset-bottomInset)) }
    func point(_ p: HistoryPoint) -> CGPoint {
        CGPoint(x: plot.minX + (p.reading.time - start) / max(1, end-start) * plot.width,
                y: plot.maxY - p.reading.remaining / 100 * plot.height)
    }
    private func ensureCurveCache() {
        guard cacheSize != bounds.size || cacheStart != start || cacheEnd != end else { return }
        func project(_ p:CGPoint) -> CGPoint {
            CGPoint(x:plot.minX+(p.x-start)/max(1,end-start)*plot.width,y:plot.maxY-p.y/100*plot.height)
        }
        func unproject(_ p:CGPoint) -> CGPoint {
            CGPoint(x:start+(p.x-plot.minX)/plot.width*(end-start),y:(plot.maxY-p.y)/plot.height*100)
        }
        let appended=points.count>=fittedPoints.count && points.prefix(fittedPoints.count).elementsEqual(fittedPoints)
        if fittedPoints.isEmpty || !appended {
            dataSegments=HistoryChartGeometry.runs(points).filter { $0.count>1 }.flatMap { run in
                HistoryChartGeometry.curveSegments(HistoryChartGeometry.roundedPath(run.map { point(points[$0]) })).map { $0.mapped(unproject) }
            }
            #if USAGE_TOPBAR_TESTING
            fullFitCount+=1
            #endif
        } else if points.count>fittedPoints.count {
            for index in fittedPoints.count..<points.count {
                guard HistoryChartGeometry.connects(points,at:index) else { continue }
                var first=index
                while first>max(0,index-HistoryChartGeometry.tailRefitIntervals),HistoryChartGeometry.connects(points,at:first) { first-=1 }
                let cut=points[first].reading.time
                var prefix:[HistoryChartGeometry.CurveSegment]=[]
                for segment in dataSegments {
                    if segment.b.x<=cut { prefix.append(segment) }
                    else if segment.a.x<cut { prefix.append(segment.leftPart(endingAt:cut));break }
                    else { break }
                }
                var tail=Array(points[first...index]).map { point($0) }
                if let previous=prefix.last,abs(previous.b.x-cut)<0.001 { tail[0]=project(previous.b) }
                var replacement=HistoryChartGeometry.curveSegments(HistoryChartGeometry.roundedPath(tail))
                if let previous=prefix.last,abs(previous.b.x-cut)<0.001,let head=replacement.first {
                    let old=previous.mapped(project),dx=head.b.x-head.a.x
                    let y=head.a.y+old.endSlope*dx*HistoryChartGeometry.smoothingStrength
                    let c1=CGPoint(x:head.a.x+dx*HistoryChartGeometry.smoothingStrength,y:max(min(head.a.y,head.b.y),min(max(head.a.y,head.b.y),y)))
                    let c2=head.c2 ?? CGPoint(x:head.b.x-dx*HistoryChartGeometry.smoothingStrength,y:head.b.y-(head.b.y-head.a.y)*HistoryChartGeometry.smoothingStrength)
                    replacement[0]=HistoryChartGeometry.CurveSegment(a:head.a,b:head.b,c1:c1,c2:c2)
                }
                dataSegments=prefix+replacement.map { $0.mapped(unproject) }
                #if USAGE_TOPBAR_TESTING
                tailFitCount+=1;lastRefitStartTime=cut
                #endif
            }
        }
        fittedPoints=points
        projected=points.map(point)
        cachedSegments=dataSegments.map { $0.mapped(project) }
        let path=NSBezierPath();path.lineWidth=HistoryChartGeometry.strokeWidth;path.lineCapStyle = .round;path.lineJoinStyle = .round
        var previous:CGPoint?
        for segment in cachedSegments {
            if previous.map({ hypot($0.x-segment.a.x,$0.y-segment.a.y)>0.001 }) ?? true { path.move(to:segment.a) }
            if let c1=segment.c1,let c2=segment.c2 { path.curve(to:segment.b,controlPoint1:c1,controlPoint2:c2) }
            else { path.line(to:segment.b) }
            previous=segment.b
        }
        cachedStrokeMasks=[HistoryCurvePaint.strokeMask(path)]
        cacheSize=bounds.size;cacheStart=start;cacheEnd=end
        #if USAGE_TOPBAR_TESTING
        geometryBuildCount+=1
        #endif
    }
    private func nearestPoint(to x:CGFloat) -> Int? {
        var low=0,high=projected.count
        while low<high { let mid=(low+high)/2;if projected[mid].x<x { low=mid+1 } else { high=mid } }
        return [low-1,low].filter { projected.indices.contains($0) }.min { abs(projected[$0].x-x)<abs(projected[$1].x-x) }
    }
    func updateCrosshair(at location:CGPoint) {
        guard showsCrosshair || showsCompactHover,plot.contains(location) else { clearCrosshair();return }
        ensureCurveCache()
        crosshairLocation=location
        crosshairY=HistoryChartGeometry.curveY(cachedSegments,at:location.x)
        let nearest=nearestPoint(to:location.x)
        if crosshairY==nil,let nearest,abs(projected[nearest].x-location.x)<0.5 { crosshairY=projected[nearest].y }
        crosshairValue=crosshairY.map { Double((plot.maxY-$0)/plot.height*100) }
        crosshairTime=start+Double((location.x-plot.minX)/plot.width)*(end-start)
        crosshairText=crosshairValue.map { String(format:"%.1f%%",$0) } ?? ""
        crosshairOverlay.needsDisplay=true;onCrosshairChange?()
    }
    func clearCrosshair() {
        guard crosshairLocation != nil else { return }
        crosshairLocation=nil;crosshairY=nil;crosshairTime=nil;crosshairValue=nil;crosshairText="";crosshairOverlay.needsDisplay=true;onCrosshairChange?()
    }
    override func mouseMoved(with event:NSEvent) {
        let location=convert(event.locationInWindow,from:nil)
        updateCrosshair(at:location)
    }
    override func mouseExited(with event:NSEvent) { clearCrosshair() }
    fileprivate func drawCrosshair() {
        guard let location=crosshairLocation else { return }
        NSGraphicsContext.saveGraphicsState();defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect:plot).addClip()
        let ink=NSColor.labelColor
        if showsCompactHover {
            let vertical=NSBezierPath();vertical.lineWidth=0.7
            vertical.move(to:CGPoint(x:location.x,y:plot.minY));vertical.line(to:CGPoint(x:location.x,y:plot.maxY))
            ink.withAlphaComponent(0.3).setStroke();vertical.stroke()
            if let y=crosshairY {
                let dot=NSBezierPath(ovalIn:CGRect(x:location.x-3.5,y:y-3.5,width:7,height:7))
                NSColor.windowBackgroundColor.setFill();dot.fill()
                ink.setStroke();dot.lineWidth=1.5;dot.stroke()
            }
            return
        }
        let lines=NSBezierPath();lines.lineWidth=0.7
        lines.move(to:CGPoint(x:location.x,y:plot.minY));lines.line(to:CGPoint(x:location.x,y:plot.maxY))
        if let y=crosshairY {
            lines.move(to:CGPoint(x:max(plot.minX,visibleRect.minX),y:y));lines.line(to:CGPoint(x:min(plot.maxX,visibleRect.maxX),y:y))
        }
        ink.withAlphaComponent(0.3).setStroke();lines.stroke()

    }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { showsCompactHover }
    override var mouseDownCanMoveWindow:Bool { false }
    override func mouseDown(with event: NSEvent) { onOpen?() }
    func flash(_ time: Double) {
        guard window?.isVisible == true, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        pulseTimes[time] = ProcessInfo.processInfo.systemUptime
        if pulseTimer == nil {
            let timer = Timer(timeInterval: 1.0/30, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.pulseTimes = self.pulseTimes.filter { ProcessInfo.processInfo.systemUptime - $0.value < 0.9 }
                self.needsDisplay = true
                if self.pulseTimes.isEmpty { self.pulseTimer?.invalidate(); self.pulseTimer = nil }
            }
            RunLoop.main.add(timer, forMode: .common); pulseTimer = timer
        }
    }
    deinit { pulseTimer?.invalidate() }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let ink = effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(srgbRed:0.64,green:0.75,blue:0.68,alpha:1):NSColor(srgbRed:0.29,green:0.43,blue:0.35,alpha:1)
        let resetConnectors=points.indices.compactMap { index -> (CGPoint,CGPoint)? in
            guard index>0 else { return nil }
            return HistoryChartGeometry.resetConnector(points,at:index,from:point(points[index-1]),to:point(points[index]))
        }
        // Static inward fade with crisp boundaries. Merge overlapping bands once.
        let colors=[NSColor.systemGreen.withAlphaComponent(0.16),NSColor.systemGreen.withAlphaComponent(0.035),NSColor.systemGreen.withAlphaComponent(0.16)]
        let gradient=NSGradient(colors:colors,atLocations:[0,0.5,1],colorSpace:.deviceRGB)!
        NSGraphicsContext.saveGraphicsState()
        let bandWidth=viewportPlotWidth>0 ? viewportPlotWidth:plot.width
        let outline=HistoryChartGeometry.resetBandOutline(connectors:resetConnectors,plot:plot,viewportWidth:bandWidth,compact:showsCompactHover)
        let context=NSGraphicsContext.current!.cgContext
        context.addPath(outline);context.clip()
        for band in HistoryChartGeometry.resetBands(connectors:resetConnectors,plot:plot,viewportWidth:bandWidth) {
            NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:band).addClip()
            gradient.draw(in:band,angle:0);NSGraphicsContext.restoreGraphicsState()
        }
        context.addPath(outline);context.setLineWidth(0.5);context.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.3).cgColor);context.strokePath()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:plot).addClip()
        let daily=NSBezierPath();daily.lineWidth=0.5
        for time in HistoryChartGeometry.halfDayTicks(start:start,end:end) {
            let x=plot.minX+(time-start)/max(1,end-start)*plot.width
            daily.move(to:CGPoint(x:x,y:plot.minY));daily.line(to:CGPoint(x:x,y:plot.maxY))
        }
        NSColor.labelColor.withAlphaComponent(0.07).setStroke();daily.stroke()
        NSGraphicsContext.restoreGraphicsState()
        for percent in [0.0, 50, 100] {
            let y = plot.maxY - percent/100 * plot.height
            let grid = NSBezierPath(); grid.move(to: CGPoint(x: bounds.minX, y: y)); grid.line(to: CGPoint(x: bounds.maxX, y: y))
            NSColor.labelColor.withAlphaComponent(0.08).setStroke(); grid.lineWidth = 0.5; grid.stroke()
        }
        // One stroke per continuous run: no independently capped tiny segments.
        NSGraphicsContext.saveGraphicsState()
        ensureCurveCache()
        if cachedGradient == nil { cachedGradient=HistoryCurvePaint.gradient(curveGradient) }
        for mask in cachedStrokeMasks {
            HistoryCurvePaint.draw(mask:mask,plot:plot,gradient:cachedGradient!)
        }
        NSGraphicsContext.restoreGraphicsState()
        for index in points.indices {
            let current = points[index], b = point(current)
            if index>0, let (from,to)=HistoryChartGeometry.resetConnector(points,at:index,from:point(points[index-1]),to:b) {
                NSGraphicsContext.saveGraphicsState()
                let jump=NSBezierPath();jump.move(to:from);jump.line(to:to)
                jump.lineWidth=2;jump.lineCapStyle = .round;jump.setLineDash([2,4],count:2,phase:0)
                ink.withAlphaComponent(0.28).setStroke();jump.stroke()
                NSGraphicsContext.restoreGraphicsState()
            }
            if HistoryChartGeometry.isLongGap(points, at:index) {
                let a = point(points[index-1])
                NSGraphicsContext.saveGraphicsState()
                let (from, to) = HistoryChartGeometry.gapMarker(from:a,to:b)
                let gap = NSBezierPath(); gap.move(to:from); gap.line(to:to)
                gap.lineWidth=1.5; gap.lineCapStyle = .round
                gap.setLineDash([2,2],count:2,phase:0)
                ink.withAlphaComponent(0.35).setStroke(); gap.stroke()
                NSGraphicsContext.restoreGraphicsState()
            }
            if visibleRect.insetBy(dx: -20, dy: 0).contains(b) {
                // Only truly isolated evidence needs a permanent dot. Connected samples
                // are represented by the trend line and revealed individually on hover.
                if HistoryChartGeometry.isolated(points, at: index) {
                    ink.setFill()
                    NSBezierPath(ovalIn: CGRect(x:b.x-3, y:b.y-3, width:6, height:6)).fill()
                }

            }
        }
        // Independent top marker band. Cluster nearby markers rather than overlap them.
        var groups:[[HistoryPoint]]=[]
        for p in points where p.event?.showsReset == true {
            if let last=groups.last, point(p).x-point(last[0]).x<32 { groups[groups.count-1].append(p) }
            else { groups.append([p]) }
        }
        for group in groups {
            let x=group.map { point($0).x }.reduce(0,+)/CGFloat(group.count)
            if x>=visibleRect.minX-16 && x<=visibleRect.maxX+16 {
                drawEvent(group[0].event!.kind,at:CGPoint(x:x,y:18),time:group[0].reading.time,ink:ink,count:group.count)
            }
        }
        if let last = points.last, min(now(), end) - last.reading.time >= HistoryChartGeometry.longGapThreshold {
            let a = point(last)
            let right = plot.minX + (min(now(), end)-start) / max(1,end-start) * plot.width
            let path = NSBezierPath(); path.move(to: a); path.line(to: CGPoint(x:right,y:a.y))
            path.setLineDash([3,5], count:2, phase:0); path.lineWidth=1.4; path.lineCapStyle = .round
            ink.withAlphaComponent(0.25).setStroke(); path.stroke()
        }
        if points.isEmpty {
            ("等待有效采样" as NSString).draw(at: CGPoint(x: visibleRect.midX-45, y: plot.midY), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
        }
    }
    static func resetIcon(_ kind: HistoryResetKind) -> NSImage {
        NSImage(size: NSSize(width:28,height:28), flipped:true) { _ in
            let chart = HistoryChartView(frame:NSRect(x:0,y:0,width:28,height:28))
            chart.drawEvent(kind,at:CGPoint(x:14,y:12),time:0,ink:.labelColor)
            return true
        }
    }
    func drawEvent(_ kind: HistoryResetKind, at point: CGPoint, time: Double, ink: NSColor, count:Int=1) {
        let center=CGPoint(x:max(12,min(bounds.width-12,point.x)),y:12)
        NSGraphicsContext.saveGraphicsState();defer { NSGraphicsContext.restoreGraphicsState() }
        let scale=NSAffineTransform();scale.translateX(by:center.x,yBy:center.y)
        scale.scale(by:showsCrosshair ? 0.78:0.68);scale.translateX(by:-center.x,yBy:-center.y);scale.concat()
        let pulse=pulseTimes[time].map { max(0,1-(ProcessInfo.processInfo.systemUptime-$0)/0.9) } ?? 0
        if pulse>0 {
            ink.withAlphaComponent(0.16*pulse).setFill()
            NSBezierPath(ovalIn:CGRect(x:center.x-15,y:center.y-15,width:30,height:30)).fill()
        }
        NSGraphicsContext.saveGraphicsState()
        ink.setStroke()
        if count>1 {
            let badge=NSBezierPath(roundedRect:CGRect(x:center.x-12,y:center.y-12,width:24,height:24),xRadius:8,yRadius:8)
            badge.lineWidth=1.6;badge.stroke()
            let text="\(count)" as NSString
            let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedDigitSystemFont(ofSize:11,weight:.medium),.foregroundColor:ink]
            let size=text.size(withAttributes:attributes)
            text.draw(at:CGPoint(x:center.x-size.width/2,y:center.y-size.height/2),withAttributes:attributes)
        } else {
            func arrow(_ c:CGPoint,_ outerRadius:CGFloat) {
                // Grow the stroke inward so the outer silhouette stays unchanged.
                let radius=outerRadius-(1.7*1.15-1.7)/2
                let path=NSBezierPath();path.lineWidth=1.7*1.15;path.lineCapStyle = .round;path.lineJoinStyle = .round
                // Cubic circular arc ends inside a tangent-aligned rounded filled head.
                let begin = -CGFloat.pi/6,end = CGFloat.pi*260/180
                func polar(_ angle:CGFloat) -> CGPoint { CGPoint(x:c.x+cos(angle)*radius,y:c.y+sin(angle)*radius) }
                path.move(to:polar(begin))
                for index in 0..<5 {
                    let a=begin+(end-begin)*CGFloat(index)/5,b=begin+(end-begin)*CGFloat(index+1)/5
                    let p=polar(a),q=polar(b),k=4/3*tan((b-a)/4)*radius
                    path.curve(to:q,controlPoint1:CGPoint(x:p.x-sin(a)*k,y:p.y+cos(a)*k),controlPoint2:CGPoint(x:q.x+sin(b)*k,y:q.y-cos(b)*k))
                }
                path.stroke()
                let tip=CGPoint(x:c.x+0.2,y:c.y-radius),length=radius*0.48*1.15,halfWidth=radius*0.25*1.15
                let corners=[tip,CGPoint(x:tip.x-length,y:tip.y-halfWidth),CGPoint(x:tip.x-length,y:tip.y+halfWidth)]
                let head=NSBezierPath()
                for index in 0..<3 {
                    let a=corners[(index+2)%3],b=corners[index],c=corners[(index+1)%3]
                    let entry=CGPoint(x:b.x+(a.x-b.x)*0.2,y:b.y+(a.y-b.y)*0.2),exit=CGPoint(x:b.x+(c.x-b.x)*0.2,y:b.y+(c.y-b.y)*0.2)
                    if index==0 { head.move(to:entry) } else { head.line(to:entry) }
                    head.curve(to:exit,controlPoint1:CGPoint(x:entry.x+(b.x-entry.x)*2/3,y:entry.y+(b.y-entry.y)*2/3),controlPoint2:CGPoint(x:exit.x+(b.x-exit.x)*2/3,y:exit.y+(b.y-exit.y)*2/3))
                }
                head.close();ink.setFill();head.fill()
            }
            if kind == .card {
                let x=center.x,y=center.y,card=NSBezierPath()
                // Keep stroke caps clear of the reset arc at compact raster sizes.
                card.move(to:CGPoint(x:x,y:y+7));card.line(to:CGPoint(x:x-8,y:y+7))
                card.curve(to:CGPoint(x:x-11,y:y+4),controlPoint1:CGPoint(x:x-10,y:y+7),controlPoint2:CGPoint(x:x-11,y:y+6))
                card.line(to:CGPoint(x:x-11,y:y-4));card.curve(to:CGPoint(x:x-8,y:y-7),controlPoint1:CGPoint(x:x-11,y:y-6),controlPoint2:CGPoint(x:x-10,y:y-7))
                card.line(to:CGPoint(x:x+4,y:y-7));card.curve(to:CGPoint(x:x+7,y:y-4),controlPoint1:CGPoint(x:x+6,y:y-7),controlPoint2:CGPoint(x:x+7,y:y-6))
                card.line(to:CGPoint(x:x+7,y:y-2));card.lineWidth=1.7;card.lineCapStyle = .round;card.lineJoinStyle = .round;card.stroke()
                let stripe=NSBezierPath();stripe.move(to:CGPoint(x:x-8,y:y-2));stripe.line(to:CGPoint(x:x+3,y:y-2));stripe.lineWidth=1.7;stripe.lineCapStyle = .round;stripe.stroke()
                arrow(CGPoint(x:x+7,y:y+6),4.7)
            } else {
                arrow(CGPoint(x:center.x,y:center.y+1),9.5)
                if kind == .cycle {
                    // Clock hands inside the existing circular arrow: distinct at small sizes.
                    let hands=NSBezierPath();hands.lineWidth=1.8;hands.lineCapStyle = .round;hands.lineJoinStyle = .round
                    hands.move(to:CGPoint(x:center.x,y:center.y-4))
                    hands.line(to:CGPoint(x:center.x,y:center.y+1))
                    hands.line(to:CGPoint(x:center.x+4,y:center.y+3))
                    hands.stroke()
                    ink.setFill();NSBezierPath(ovalIn:CGRect(x:center.x-1,y:center.y,width:2,height:2)).fill()
                }
                if kind == .special {
                    let star=NSBezierPath();let x=center.x,y=center.y+1
                    star.move(to:CGPoint(x:x,y:y-5));star.curve(to:CGPoint(x:x+5,y:y),controlPoint1:CGPoint(x:x+0.625,y:y-2.25),controlPoint2:CGPoint(x:x+2.25,y:y-0.625))
                    star.curve(to:CGPoint(x:x,y:y+5),controlPoint1:CGPoint(x:x+2.25,y:y+0.625),controlPoint2:CGPoint(x:x+0.625,y:y+2.25))
                    star.curve(to:CGPoint(x:x-5,y:y),controlPoint1:CGPoint(x:x-0.625,y:y+2.25),controlPoint2:CGPoint(x:x-2.25,y:y+0.625))
                    star.curve(to:CGPoint(x:x,y:y-5),controlPoint1:CGPoint(x:x-2.25,y:y-0.625),controlPoint2:CGPoint(x:x-0.625,y:y-2.25))
                    star.close();ink.setFill();star.fill()
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

}

private final class HistoryCrosshairOverlay:NSView {
    weak var chart:HistoryChartView?
    init(chart:HistoryChartView) {
        self.chart=chart;super.init(frame:.zero)
        wantsLayer=true;layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    required init?(coder:NSCoder) { fatalError() }
    override var isFlipped:Bool { true }
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect:NSRect) { chart?.drawCrosshair() }
}

// One native material surface per readout, reused as the pointer moves.
private final class HistoryBackdropTint:NSView {
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect:NSRect) {
        let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        NSColor.windowBackgroundColor.withAlphaComponent(reduce ? 1:0.20).setFill()
        NSBezierPath(rect:bounds).fill()
        NSColor.labelColor.withAlphaComponent(0.08).setStroke()
        let edge=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:12,yRadius:12);edge.lineWidth=1;edge.stroke()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance();needsDisplay=true }
}
private final class HistoryFlippedView:NSView { override var isFlipped:Bool { true } }
private final class HistoryReadoutText:NSView {
    var text="" { didSet { needsDisplay=true } }
    override var isFlipped:Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        (text as NSString).draw(at:CGPoint(x:7,y:4),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:11,weight:.semibold),.foregroundColor:NSColor.labelColor])
    }
}
private final class HistoryMaterialSurface:NSView {
    let content=NSView()
    private var material:NSView?
    private var reduced:Bool?
    override init(frame:NSRect) { super.init(frame:frame);refreshMaterial() }
    required init?(coder:NSCoder) { fatalError() }
    func refreshMaterial() {
        let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        guard reduced != reduce else { return };reduced=reduce
        content.removeFromSuperview();material?.removeFromSuperview()
        if #available(macOS 26.0,*), !reduce {
            let glass=NSGlassEffectView(frame:bounds);glass.style = .regular;glass.cornerRadius=7
            glass.contentView=content;material=glass
        } else if !reduce {
            let effect=NSVisualEffectView(frame:bounds);effect.material = .popover
            effect.blendingMode = .withinWindow;effect.state = .active
            effect.wantsLayer=true;effect.layer?.cornerRadius=7;effect.layer?.masksToBounds=true
            effect.addSubview(content);material=effect
        } else { material=content }
        let surface=material!;surface.frame=bounds;surface.autoresizingMask=[.width,.height]
        addSubview(surface);content.frame=bounds;content.autoresizingMask=[.width,.height]
        needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        if reduced == true {
            NSColor.controlBackgroundColor.setFill();NSBezierPath(roundedRect:bounds,xRadius:7,yRadius:7).fill()
            NSColor.separatorColor.setStroke();let edge=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:7,yRadius:7);edge.lineWidth=1;edge.stroke()
        }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance();needsDisplay=true;content.subviews.forEach { $0.needsDisplay=true } }
}

final class HistoryHoverLabels:NSView {
    struct Readout { let kind:String,text:String,rect:CGRect }
    private(set) var readouts:[Readout]=[]
    private var surfaces:[String:HistoryMaterialSurface]=[:]
    private var labels:[String:HistoryReadoutText]=[:]
    private let materialContent=HistoryFlippedView()
    override func layout() { super.layout();subviews.first?.frame=bounds;materialContent.frame=bounds }
    func refreshMaterials() { surfaces.values.forEach { $0.refreshMaterial() } }
    private func syncLabels() {
        for (kind,surface) in surfaces { surface.isHidden = !readouts.contains { $0.kind==kind } }
        for item in readouts {
            let surface:HistoryMaterialSurface
            if let old=surfaces[item.kind] { surface=old }
            else {
                surface=HistoryMaterialSurface(frame:item.rect)
                let label=HistoryReadoutText(frame:surface.bounds);label.autoresizingMask=[.width,.height]
                surface.content.addSubview(label);labels[item.kind]=label;surfaces[item.kind]=surface
                materialContent.addSubview(surface)
            }
            surface.frame=item.rect;surface.isHidden=false;labels[item.kind]?.text=item.text
        }
    }
    override var isFlipped:Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame);wantsLayer=true;layerContentsRedrawPolicy = .onSetNeedsDisplay
        if #available(macOS 26.0,*) {
            let group=NSGlassEffectContainerView(frame:bounds);group.spacing=0;group.contentView=materialContent
            group.autoresizingMask=[.width,.height];addSubview(group)
        } else { materialContent.frame=bounds;materialContent.autoresizingMask=[.width,.height];addSubview(materialContent) }
    }
    required init?(coder:NSCoder) { fatalError() }
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    private var attributes:[NSAttributedString.Key:Any] { [.font:NSFont.monospacedDigitSystemFont(ofSize:11,weight:.semibold),.foregroundColor:NSColor.labelColor] }
    func update(chart:HistoryChartView) {
        readouts=[];defer { syncLabels() }
        guard chart.showsCrosshair || chart.showsCompactHover,let location=chart.crosshairLocation,let time=chart.crosshairTime else { return }
        let p=convert(chart.plot.intersection(chart.visibleRect),from:chart)
        let pointer=convert(location,from:chart)
        guard !p.isEmpty,pointer.x>=p.minX,pointer.x<=p.maxX else { return }
        func size(_ text:String) -> CGSize { let s=(text as NSString).size(withAttributes:attributes);return CGSize(width:ceil(s.width)+14,height:ceil(s.height)+8) }
        let f=DateFormatter()
        let dateValue=Date(timeIntervalSince1970:time)
        let sameDay=Calendar.current.isDate(dateValue,inSameDayAs:Date(timeIntervalSince1970:chart.end))
        f.dateFormat=chart.showsCompactHover ? (sameDay ? "HH:mm":"M/d HH:mm") : "MM/dd HH:mm"
        let date=f.string(from:Date(timeIntervalSince1970:time)),ds=size(date)
        let dateBox=CGRect(x:max(p.minX,min(pointer.x-ds.width/2,p.maxX-ds.width)),y:min(bounds.height-ds.height-3,p.maxY+7),width:ds.width,height:ds.height)
        readouts.append(Readout(kind:"time",text:date,rect:dateBox))
        guard let y=chart.crosshairY,!chart.crosshairText.isEmpty else { return }
        let cross=convert(CGPoint(x:location.x,y:y),from:chart),text=chart.crosshairText,vs=size(text)
        let left=CGRect(x:min(8,max(4,p.minX-vs.width-2)),y:max(p.minY,min(cross.y-vs.height/2,p.maxY-vs.height)),width:vs.width,height:vs.height)
        if chart.showsCrosshair { readouts.append(Readout(kind:"axis",text:text,rect:left)) }
        var x=cross.x+12
        if x+vs.width>p.maxX-2 { x=cross.x-vs.width-12 }
        x=max(p.minX+2,min(x,p.maxX-vs.width-2))
        var labelY=cross.y-vs.height-12
        if labelY<p.minY+2 { labelY=cross.y+12 }
        labelY=max(p.minY+2,min(labelY,p.maxY-vs.height-2))
        readouts.append(Readout(kind:"point",text:text,rect:CGRect(x:x,y:labelY,width:vs.width,height:vs.height)))
    }

}

enum HistoryResetLegend {
    static func text(_ zh: String, _ en: String) -> String { Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en }
    static func label(_ kind: HistoryResetKind) -> String {
        switch kind {
        case .cycle: return text("自然重置", "Scheduled reset")
        case .card: return text("重置卡", "Reset credit")
        case .special: return text("特殊重置", "Special reset")
        case .unknown: return text("原因未知", "Unknown cause")
        }
    }
    static var explanation: String { text("绿条表示额度恢复；标记时间为首次观测时间。", "Green bands show quota recovery; markers indicate when it was first observed.") }
    static var tooltip: String { [.cycle,.card,.special,.unknown].map { label($0) }.joined(separator: "\n") + "\n" + explanation }
}

final class HistoryPanelContent: NSView {
    let chart = HistoryChartView()
    let scroll = NSScrollView()
    let seriesButton = NSPopUpButton()
    let nowButton = NSButton(title:"回到现在",target:nil,action:nil)
    let message = NSTextField(labelWithString: "")
    let resetLegend = NSPopUpButton(frame: .zero, pullsDown: true)
    private let store: any HistoryDataSource
    private let expanded: Bool
    private var seriesKeys: [String] = []
    private var selected: String?
    private var following = true
    private var refreshing = false
    private var observer: NSObjectProtocol?
    private var accessibilityObserver:NSObjectProtocol?
    private let nowSurface=HistoryMaterialSurface()
    private let backdrop=NSVisualEffectView()
    private let backdropTint=HistoryBackdropTint()
    private var axis = HistoryAxisView()
    let dateAxis = HistoryDateAxisView()
    let hoverLabels = HistoryHoverLabels()
    init(store: any HistoryDataSource, expanded: Bool) {
        self.store=store; self.expanded=expanded
        super.init(frame:CGRect(x:0,y:0,width:expanded ? 820:410,height:expanded ? 330:195))
        chart.showsCrosshair=expanded
        chart.showsCompactHover = !expanded
        backdrop.frame=bounds;backdrop.autoresizingMask=[.width,.height]
        backdrop.material = .underWindowBackground;backdrop.blendingMode = .behindWindow;backdrop.state = .active
        backdrop.alphaValue=1
        addSubview(backdrop)
        backdropTint.frame=bounds;backdropTint.autoresizingMask=[.width,.height];addSubview(backdropTint)
        seriesButton.bezelStyle = .rounded; seriesButton.font = .systemFont(ofSize:11,weight:.medium)
        seriesButton.target=self; seriesButton.action=#selector(selectSeries)
        nowButton.bezelStyle = .rounded; nowButton.font = .systemFont(ofSize:11); nowButton.target=self; nowButton.action=#selector(goNow)
        addSubview(seriesButton); if expanded { nowButton.isBordered=false;nowSurface.content.addSubview(nowButton);addSubview(nowSurface) }
        resetLegend.addItem(withTitle: HistoryResetLegend.text("图例", "Legend"))
        for kind: HistoryResetKind in [.cycle,.card,.special,.unknown] {
            resetLegend.addItem(withTitle: HistoryResetLegend.label(kind))
            resetLegend.lastItem?.image = HistoryChartView.resetIcon(kind)
            resetLegend.lastItem?.isEnabled = false
        }
        resetLegend.toolTip = nil
        resetLegend.setAccessibilityLabel(HistoryResetLegend.text("重置图例", "Reset legend"))
        resetLegend.font = .systemFont(ofSize:10)
        addSubview(resetLegend)
        chart.toolTip = nil
        chart.setAccessibilityLabel(HistoryResetLegend.text("剩余额度历史，纵轴0至100百分比。", "Remaining quota history, 0 to 100 percent. ") + HistoryResetLegend.tooltip)
        message.font = .systemFont(ofSize:10); message.textColor = .secondaryLabelColor; addSubview(message)
        scroll.drawsBackground=false; scroll.hasHorizontalScroller=false; scroll.hasVerticalScroller=false
        scroll.horizontalScrollElasticity = expanded && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .allowed : .none; scroll.verticalScrollElasticity = .none
        scroll.documentView=chart; addSubview(scroll); addSubview(axis)
        dateAxis.chart=chart;dateAxis.viewport=scroll.contentView;addSubview(dateAxis)
        addSubview(hoverLabels)
        chart.onCrosshairChange = { [weak self] in self?.updateHoverLabels() }
        scroll.contentView.postsBoundsChangedNotifications=true
        observer=NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,object:scroll.contentView,queue:.main) { [weak self] _ in
            guard let self else { return }
            self.dateAxis.needsDisplay=true
            self.chart.clearCrosshair()
            guard !self.refreshing else { return }
            self.following = self.scroll.contentView.bounds.maxX >= self.chart.bounds.maxX-2
        }
        accessibilityObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self else { return }
            self.hoverLabels.refreshMaterials();self.nowSurface.refreshMaterial()
            self.backdrop.alphaValue=1;self.backdropTint.needsDisplay=true
            self.scroll.horizontalScrollElasticity=self.expanded && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .allowed:.none
        }
        refresh()
    }
    required init?(coder:NSCoder) { fatalError() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) };if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) } }
    override func layout() {
        super.layout()
        seriesButton.frame=CGRect(x:expanded ? 86:10,y:bounds.height-(expanded ? 35:27),width:120,height:24)
        nowSurface.frame=CGRect(x:bounds.width-110,y:bounds.height-35,width:92,height:24)
        nowButton.frame=nowSurface.bounds;nowButton.autoresizingMask=[.width,.height]
        resetLegend.frame=CGRect(x:bounds.width-(expanded ? 178:72),y:bounds.height-(expanded ? 35:27),width:62,height:24)
        let messageX: CGFloat = seriesButton.isHidden ? (expanded ? 86:10) : (expanded ? 218:140)
        message.frame=CGRect(x:messageX,y:bounds.height-(expanded ? 31:23),width:max(1,resetLegend.frame.minX-messageX-8),height:18)
        let headerNeeded = true // Keep the reset legend available in compact and expanded charts.
        let chartHeight = bounds.height - (expanded ? (headerNeeded ? 44:24):(headerNeeded ? 28:12))
        let gutter:CGFloat=expanded ? 64:32
        let bottom:CGFloat=expanded ? 12:6,right:CGFloat=expanded ? 14:8
        scroll.frame=CGRect(x:gutter,y:bottom,width:bounds.width-gutter-right,height:chartHeight)
        axis.frame=CGRect(x:expanded ? 12:8,y:bottom,width:gutter-10,height:chartHeight)
        axis.topInset=chart.topInset;axis.bottomInset=chart.bottomInset
        dateAxis.frame=CGRect(x:gutter,y:bottom,width:bounds.width-gutter-right,height:24)
        hoverLabels.frame=bounds
        updateGeometry()
    }
    private func updateHoverLabels() {
        hoverLabels.update(chart:chart)
        axis.suppressedRect=hoverLabels.readouts.first(where: { $0.kind=="axis" }).map { axis.convert($0.rect,from:hoverLabels) }
        dateAxis.suppressedRect=hoverLabels.readouts.first(where: { $0.kind=="time" }).map { dateAxis.convert($0.rect,from:hoverLabels) }
    }
    func refreshIfVisible() {
        guard let window, window.isVisible, !window.isMiniaturized else { return }
        refresh()
    }
    func refresh() {
        let keys=store.series(); if keys != seriesKeys {
            seriesKeys=keys; seriesButton.removeAllItems(); seriesButton.addItems(withTitles:keys.map(HistoryChartGeometry.label))
            if let selected, let index=keys.firstIndex(of:selected) { seriesButton.selectItem(at:index) }
            else { selected=keys.first }
        }
        if selected == nil { selected=keys.first }
        seriesButton.isHidden = keys.count <= 1
        seriesButton.toolTip = nil
        seriesButton.setAccessibilityLabel("额度周期")
        chart.points=selected.map { store.visiblePoints(series:$0) } ?? []
        message.stringValue=store.isSimulated ? "模拟数据" : store.error ?? (store.activeAccount == nil ? HistoryResetLegend.text("等待额度数据", "Waiting for quota data") : "")
        needsLayout = true
        updateGeometry()
    }
    private func updateGeometry() {
        guard scroll.bounds.width > 0 else { return }
        refreshing=true; defer { refreshing=false }
        let oldEnd=chart.end, oldStart=chart.start
        let oldVisibleTime=oldStart + scroll.contentView.bounds.minX / max(1,chart.bounds.width) * (oldEnd-oldStart)
        chart.viewportPlotWidth=max(1,scroll.bounds.width-16)
        let now=Date().timeIntervalSince1970, days=expanded ? 7.0:4.0
        let earliest=chart.points.first?.reading.time ?? now
        chart.end=now
        chart.start=expanded ? min(now-7*86400,earliest) : now-4*86400
        let width=scroll.bounds.width * (chart.end-chart.start)/(days*86400)
        chart.frame=CGRect(x:0,y:0,width:max(scroll.bounds.width,width),height:scroll.bounds.height)
        let x=following ? max(0,width-scroll.bounds.width) : max(0,min(width-scroll.bounds.width,(oldVisibleTime-chart.start)/(chart.end-chart.start)*width))
        scroll.contentView.scroll(to:CGPoint(x:x,y:0)); scroll.reflectScrolledClipView(scroll.contentView)
        chart.clearCrosshair();chart.needsDisplay=true;dateAxis.needsDisplay=true
    }
    @objc private func selectSeries() { if seriesKeys.indices.contains(seriesButton.indexOfSelectedItem) { selected=seriesKeys[seriesButton.indexOfSelectedItem]; following=true; refresh() } }
    @objc private func goNow() { following=true; updateGeometry() }
}
// Viewport-owned axis: never draw viewport-clamped labels into the scroll document's cached pixels.
final class HistoryDateAxisView: NSView {
    var suppressedRect:CGRect? { didSet { if oldValue != suppressedRect { needsDisplay=true } } }
    weak var chart: HistoryChartView?
    weak var viewport: NSClipView?
    override var isFlipped:Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame)
        // A separate backing surface prevents NSClipView's scroll blits from copying
        // sibling date pixels. AppKit clears this transparent layer before redraw.
        wantsLayer=true;layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    required init?(coder:NSCoder) { fatalError() }
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    override var wantsUpdateLayer:Bool { true }
    override func updateLayer() {
        guard bounds.width>0,bounds.height>0 else { layer?.contents=nil;return }
        // Replace the entire transparent surface each frame. Incremental drawing can
        // leave old glyph pixels behind after elastic scrolling on the compositor.
        let size=bounds.size
        let image=NSImage(size:size,flipped:true) { [weak self] _ in
            self?.effectiveAppearance.performAsCurrentDrawingAppearance { self?.drawLabels() }
            return true
        }
        var rect=CGRect(origin:.zero,size:size)
        layer?.contents=image.cgImage(forProposedRect:&rect,context:nil,hints:nil)
        layer?.contentsScale=window?.backingScaleFactor ?? 2
    }
    private func drawLabels() {
        guard let chart,let viewport else { return }
        let formatter=DateFormatter();formatter.dateFormat="M/d"
        let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.secondaryLabelColor]
        for tick in HistoryChartGeometry.dateTicks(start:chart.start,end:chart.end,documentWidth:chart.bounds.width,offset:viewport.bounds.minX) {
            let text=formatter.string(from:Date(timeIntervalSince1970:tick.time)) as NSString
            let width=text.size(withAttributes:attributes).width,x=tick.x-width/2
            // Keep natural tick positions; partial edge labels are omitted, never stuck to the viewport edge.
            guard x>=3,x+width<=bounds.width-3 else { continue }
            if suppressedRect?.intersects(CGRect(x:x,y:2,width:width,height:14)) == true { continue }
            text.draw(at:CGPoint(x:x,y:2),withAttributes:attributes)
        }
    }
}
private final class HistoryAxisView: NSView {
    var topInset=HistoryChartGeometry.plotTop,bottomInset=HistoryChartGeometry.plotBottom
    var suppressedRect:CGRect? { didSet { if oldValue != suppressedRect { needsDisplay=true } } }
    override init(frame:NSRect) { super.init(frame:frame);wantsLayer=true;layerContentsRedrawPolicy = .onSetNeedsDisplay }
    required init?(coder:NSCoder) { fatalError() }
    override var isFlipped:Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        for value in [0.0,50,100] {
            let y=topInset+(bounds.height-topInset-bottomInset)*(1-value/100)-6
            if suppressedRect?.intersects(CGRect(x:2,y:y,width:28,height:14)) == true { continue }
            ("\(Int(value))" as NSString).draw(at:CGPoint(x:2,y:y),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:10,weight:.regular),.foregroundColor:NSColor.secondaryLabelColor])
        }
    }
}

final class HistoryWindowController: NSObject, NSWindowDelegate {
    private let store: any HistoryDataSource
    private let popover=NSPopover()
    private var window:NSWindow?
    private var compact:HistoryPanelContent?
    private var full:HistoryPanelContent?
    var curveGradient=ProgressGradientSettings.standard { didSet { compact?.chart.curveGradient=curveGradient;full?.chart.curveGradient=curveGradient } }
    var dark=true { didSet { if oldValue != dark { updateAppearance() } } }
    init(store:QuotaHistoryStore) {
        self.store=HistorySourcePolicy.presentation(real:store)
        super.init()
        store.onChange = { [weak self] in
            guard let self, !self.store.isSimulated else { return }
            self.compact?.refreshIfVisible(); self.full?.refreshIfVisible()
        }
        store.onNewEvent = { [weak self] point in
            guard self?.store.isSimulated == false else { return }
            self?.compact?.chart.flash(point.reading.time); self?.full?.chart.flash(point.reading.time)
        }
    }
    func toggle(relativeTo button:NSView) {
        if popover.isShown { popover.performClose(nil); return }
        let content=HistoryPanelContent(store:store,expanded:false)
        content.chart.curveGradient=curveGradient
        content.chart.onOpen = { [weak self] in self?.showWindow() }
        compact=content
        let controller=NSViewController(); controller.view=content
        popover.contentViewController=controller; popover.contentSize=content.frame.size; popover.behavior = .transient
        updateAppearance(); popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
    }
    func windowDidDeminiaturize(_ notification: Notification) { full?.refresh() }
    func showWindow() {
        popover.performClose(nil)
        if window == nil {
            let content=HistoryPanelContent(store:store,expanded:true); full=content
            content.chart.curveGradient=curveGradient
            let w=NSWindow(contentRect:content.frame,styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
            w.title=AppVariant.isTesting ? "额度历史 · 测试版" : "额度历史"; w.titlebarAppearsTransparent=true;w.titleVisibility = .hidden;w.titlebarSeparatorStyle = .none;w.isMovableByWindowBackground=true;w.isOpaque=false;w.backgroundColor = .clear; w.contentView=content; w.isReleasedWhenClosed=false; w.delegate=self
            w.acceptsMouseMovedEvents=true;w.minSize=NSSize(width:600,height:280); w.center(); window=w
        }
        full?.refresh(); updateAppearance(); NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil)
    }
    #if USAGE_TOPBAR_TESTING
    // Finite, explicitly invoked native-window interaction recording; absent from release builds.
    private var scrollExercise: Timer?
    func exerciseScroll() {
        showWindow()
        guard let content=full,scrollExercise==nil else { return }
        var frame=0
        var trace:[[String:Any]]=[]
        let path=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("usage-topbar-testing-scroll.json")
        scrollExercise=Timer.scheduledTimer(withTimeInterval:1.0/60,repeats:true) { [weak self,weak content] timer in
            guard let self,let content else { timer.invalidate();return }
            let offset=content.scroll.contentView.bounds.minX
            let ticks=HistoryChartGeometry.dateTicks(start:content.chart.start,end:content.chart.end,documentWidth:content.chart.bounds.width,offset:offset)
            trace.append(["frame":frame,"offset":offset,"maxOffset":content.chart.bounds.width-content.scroll.bounds.width,
                          "crosshair":content.chart.crosshairText,"uniqueTicks":Set(ticks.map { $0.time }).count==ticks.count])
            self.window?.displayIfNeeded()
            frame+=1
            if frame>=400 {
                timer.invalidate();self.scrollExercise=nil
                if let data=try? JSONSerialization.data(withJSONObject:trace,options:.sortedKeys) { try? data.write(to:path,options:.atomic) }
            }
        }
        RunLoop.main.add(scrollExercise!,forMode:.common)
    }
    #endif
    private func updateAppearance() {
        let appearance=NSAppearance(named:dark ? .darkAqua:.aqua)
        popover.appearance=appearance; window?.appearance=appearance
        for content in [compact,full].compactMap({ $0 }) {
            content.appearance=appearance
            func redraw(_ view:NSView) { view.needsDisplay=true;view.subviews.forEach(redraw) }
            redraw(content)
        }
    }
}

/// Full-axis mapping: horizontal location 0 is 0% (bottom), location 1 is 100% (top).
enum HistoryCurvePaint {
    static func gradient(_ settings:ProgressGradientSettings) -> CGGradient {
        let stops=settings.orderedStops
        let colors=stops.map { CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,components:[$0.red,$0.green,$0.blue,$0.alpha])! }
        return CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:colors as CFArray,locations:stops.map { CGFloat($0.location) })!
    }
    static func draw(_ path:NSBezierPath,plot:CGRect,settings:ProgressGradientSettings) {
        draw(mask:strokeMask(path),plot:plot,gradient:gradient(settings))
    }
    static func strokeMask(_ path:NSBezierPath) -> CGPath {
        let curve=CGMutablePath();var vertices=[CGPoint](repeating:.zero,count:3)
        for i in 0..<path.elementCount {
            let element=vertices.withUnsafeMutableBufferPointer { path.element(at:i,associatedPoints:$0.baseAddress!) }
            switch element {
            case .moveTo:curve.move(to:vertices[0])
            case .lineTo:curve.addLine(to:vertices[0])
            case .curveTo:curve.addCurve(to:vertices[2],control1:vertices[0],control2:vertices[1])
            case .closePath:curve.closeSubpath()
            default:
                if #available(macOS 14.0,*),element == .quadraticCurveTo { curve.addQuadCurve(to:vertices[1],control:vertices[0]) }
            }
        }
        return curve.copy(strokingWithWidth:path.lineWidth,lineCap:.round,lineJoin:.round,miterLimit:10)
    }
    static func draw(mask:CGPath,plot:CGRect,gradient:CGGradient) {
        guard plot.height>0,let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState();defer { context.restoreGState() }
        context.addPath(mask);context.clip()
        context.drawLinearGradient(gradient,start:CGPoint(x:plot.minX,y:plot.maxY),end:CGPoint(x:plot.minX,y:plot.minY),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
    }
}
