import AppKit
import SwiftUI
func require(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(),message) }
let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
extension AppDelegate {
    func prepareConfigurationTest(_ prefs:ProgressGradientPreferences) {
        gradientPreferences=prefs
        historyStore=QuotaHistoryStore(file:nil)
        configureGradients()
        historyWindows.prepareConfigurationTest()
    }
    var testMenu:NSMenu { makeStatusMenu() }
    var testModel:OverlayModel { overlayModel }
    var testHistory:HistoryWindowController { historyWindows }
    var testEditor:ProgressGradientEditorController { gradientEditor }
}
extension HistoryWindowController {
    func prepareConfigurationTest() {
        compact=HistoryPanelContent(store:store,expanded:false)
        full=HistoryPanelContent(store:store,expanded:true)
        let palette=curveGradient;curveGradient=palette
    }
    var testPalettes:[ProgressGradientSettings] { [compact!.chart.curveGradient,full!.chart.curveGradient] }
}
extension ProgressGradientEditorController {
    var testSession:ProgressGradientSession { session! }
}
let domain="UsageTopbarConfigTests."+UUID().uuidString
let otherDomain=domain+".other"
let defaults=UserDefaults(suiteName:domain)!,otherDefaults=UserDefaults(suiteName:otherDomain)!
defer { defaults.removePersistentDomain(forName:domain);otherDefaults.removePersistentDomain(forName:otherDomain) }
let prefs=ProgressGradientPreferences(defaults:defaults),other=ProgressGradientPreferences(defaults:otherDefaults)
var palette=ProgressGradientSettings(stops:[ProgressGradientStop(location:0,red:1,green:0,blue:0),ProgressGradientStop(location:0.5,red:0,green:1,blue:0),ProgressGradientStop(location:1,red:0,green:0,blue:1)])
require(prefs.save(palette) && other.save(.standard),"seed isolated preferences")
let delegate=AppDelegate();delegate.prepareConfigurationTest(prefs)
require(delegate.testModel.progressGradient==palette,"installed variant loads saved palette")
require(delegate.testHistory.testPalettes.allSatisfy{$0==palette},"startup palette reaches 4/7 day charts")
let menu=delegate.testMenu
let entry=menu.items.first{$0.title=="渐变设置…"}
require(entry != nil && entry!.isEnabled && entry!.target === delegate,"both variants expose enabled gradient entry")
require(entry!.action==NSSelectorFromString("showGradientSettings"),"menu dispatches real editor method")
require(menu.items.contains{$0.title=="检查更新…"} == !AppVariant.isTesting,"updates are production-only")
require(!menu.items.contains{$0.title.contains("0.6.19")},"no stale hardcoded version")
require(AppVariant.versionLabel=="0.7.0 (52)","version is read from bundled metadata")
if AppVariant.isTesting {require(menu.items.contains{$0.title.contains(AppVariant.versionLabel)},"Testing label uses actual bundle version")}
for preference:Bool? in [nil,true,false] { if !AppVariant.isTesting {require(!HistorySourcePolicy.usesSimulation(preference:preference),"production never selects simulated history")} }
let editor=delegate.testEditor
let window=editor.prepareWindow()
require(!window.isVisible && editor.prepareWindow() === window,"editor constructs offscreen and reuses single window")
require(window.title==(AppVariant.isTesting ? "渐变设置 · 测试版":"渐变设置"),"correct channel title")
editor.testSession.edit{$0.move($0.stops[1].id,to:0.3)}
require(delegate.testModel.progressGradient==palette && prefs.load()==palette,"draft does not mutate applied or persisted palette")
editor.testSession.setPreview(true)
let preview=editor.testSession.draft
require(delegate.testModel.progressGradient==preview && delegate.testHistory.testPalettes.allSatisfy{$0==preview},"preview updates overlay plus both charts")
window.close()
require(delegate.testModel.progressGradient==palette && prefs.load()==palette && delegate.testHistory.testPalettes.allSatisfy{$0==palette},"close/cancel rolls back preview without saving")
let savedWindow=editor.prepareWindow()
editor.testSession.edit{$0.move($0.stops[1].id,to:0.7)}
let saved=editor.testSession.draft
require(editor.testSession.save(),"save succeeds")
savedWindow.close()
require(prefs.load()==saved && delegate.testModel.progressGradient==saved && delegate.testHistory.testPalettes.allSatisfy{$0==saved},"save survives close and updates charts")
let relaunched=AppDelegate();relaunched.prepareConfigurationTest(ProgressGradientPreferences(defaults:defaults))
require(relaunched.testModel.progressGradient==saved && other.load() == .standard,"settings survive recreation without crossing preference domains")
print("PASS \(AppVariant.isTesting ? "Testing":"Release"): menu, bundle version, startup settings, offscreen editor preview/save/cancel, 4/7-day linkage and domain isolation")

// Render the actual shared SwiftUI fill under each compile configuration.
@MainActor func bitmap(_ fraction:Double)->NSBitmapImageRep {
    let renderer=ImageRenderer(content:QuotaGradientFill(settings:palette,fraction:fraction).frame(width:200,height:12));renderer.scale=1
    return NSBitmapImageRep(data:renderer.nsImage!.tiffRepresentation!)!
}
func rgba(_ b:NSBitmapImageRep,_ x:Int,_ y:Int)->[CGFloat] {
 let c=b.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!
 return [c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent]
}
MainActor.assumeIsolated {
 let low=bitmap(0.25),high=bitmap(0.75),full=bitmap(1),empty=bitmap(0)
 for x in [12,24,36] {
  require(zip(rgba(low,x,6),rgba(high,x,6)).allSatisfy{abs($0-$1)<0.02},"fixed color at same horizontal coordinate")
  require(zip(rgba(high,x,6),rgba(full,x,6)).allSatisfy{abs($0-$1)<0.02},"full track never compresses palette")
 }
 require(rgba(low,90,6)[3]<0.02 && rgba(high,90,6)[3]>0.98 && rgba(empty,12,6)[3]<0.02,"right clipping and zero mask")
}
func curveBitmap(_ offset:CGFloat)->NSBitmapImageRep {
 let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:180,pixelsHigh:120,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:b)
 let ctx=NSGraphicsContext.current!.cgContext;ctx.translateBy(x:0,y:120);ctx.scaleBy(x:1,y:-1)
 let path=NSBezierPath();path.lineWidth=6
 for y in [10.0,60,110] {path.move(to:CGPoint(x:20+offset,y:y));path.line(to:CGPoint(x:130+offset,y:y))}
 HistoryCurvePaint.draw(path,plot:CGRect(x:10,y:10,width:150,height:100),settings:palette)
 NSGraphicsContext.restoreGraphicsState();return b
}
let raster=curveBitmap(0),shifted=curveBitmap(12)
require(rgba(raster,70,10)[2]>0.97 && rgba(raster,70,60)[1]>0.97 && rgba(raster,70,110)[0]>0.97,"100/top maps to right stop; zero/bottom to left stop")
for y in [10,60,110] {require(zip(rgba(raster,70,y),rgba(shifted,90,y)).allSatisfy{abs($0-$1)<0.01},"horizontal scroll preserves vertical colors")}
require(rgba(raster,70,35)[3]==0,"no bridge between separate curve segments")
let now=Date(),temp=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("fixture.json")
struct Fixture:Codable {let version:Int;let points:[HistoryPoint]}
let points=(0...384).map { i in HistoryPoint(reading:HistoryReading(account:"fixture",series:"primary",time:now.timeIntervalSince1970-Double(384-i)*1800,remaining:50,resetsAt:now.timeIntervalSince1970+604800,duration:604800,cards:[],availableCards:0),gapBefore:i==100,event:nil) }
try JSONEncoder().encode(Fixture(version:1,points:points)).write(to:temp)
let store=QuotaHistoryStore(file:temp,now:now);store.receive([points.last!.reading],now:now)
for expanded in [false,true] {
 let content=HistoryPanelContent(store:store,expanded:expanded);content.chart.curveGradient=palette
 let host=NSWindow(contentRect:content.bounds,styleMask:.borderless,backing:.buffered,defer:false);host.contentView=content;content.layoutSubtreeIfNeeded()
 require(!host.isVisible,"layout remains offscreen")
 let span=content.scroll.bounds.width/content.chart.bounds.width*(content.chart.end-content.chart.start)
 require(abs(span-(expanded ? 7:4)*86400)<1,"correct real-store 4/7-day viewport")
 require(content.chart.curveGradient==palette && content.chart.points.contains{$0.gapBefore},"palette and gap retained with real store")
}
print("PASS both-config rendering: fixed horizontal palette, vertical endpoints/intermediate stop/scroll, no gap fill, real-store 4/7-day layouts; no foreground actions")

let acceptanceRoot=URL(fileURLWithPath:"/private/tmp/UsageTopbar-Acceptance-"+UUID().uuidString,isDirectory:true)
try FileManager.default.createDirectory(at:acceptanceRoot,withIntermediateDirectories:false)
defer { try? FileManager.default.removeItem(at:acceptanceRoot) }
let token=String(acceptanceRoot.lastPathComponent.dropFirst("UsageTopbar-Acceptance-".count))
try (token+"\n").write(to:acceptanceRoot.appendingPathComponent("acceptance-marker"),atomically:true,encoding:.utf8)
let isolated=try AcceptanceContext(root:acceptanceRoot)
require(isolated.history.deletingLastPathComponent().path==acceptanceRoot.path,"history stays in explicit root")
let isolatedPrefs=ProgressGradientPreferences(defaults:isolated.preferences)
require(isolatedPrefs.save(palette),"offline preference save")
let reopened=try AcceptanceContext(root:acceptanceRoot)
require(ProgressGradientPreferences(defaults:reopened.preferences).load()==palette,"offline settings reopen from file")
do { _=try AcceptanceContext(root:URL(fileURLWithPath:"/private/tmp"));preconditionFailure("unmarked root accepted") } catch {}
print("PASS marked offline acceptance root validation and file preferences persistence")
