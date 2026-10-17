import AppKit
import SwiftUI
let app=NSApplication.shared
app.setActivationPolicy(.accessory)
@MainActor func render(_ fraction:Double) -> NSBitmapImageRep {
    let renderer=ImageRenderer(content:QuotaGradientFill(settings:.standard,fraction:fraction).frame(width:200,height:12))
    renderer.scale=1
    return NSBitmapImageRep(data:renderer.nsImage!.tiffRepresentation!)!
}
try MainActor.assumeIsolated {
let low=render(0.25),high=render(0.75),full=render(1),empty=render(0)
func check(_ b:Bool,_ m:String) { if !b { fatalError(m) } }
func color(_ bitmap:NSBitmapImageRep,_ x:Int) -> NSColor { bitmap.colorAt(x:x,y:6)!.usingColorSpace(.sRGB)! }
for x in [12,24,36] {
    let a=color(low,x),b=color(high,x),c=color(full,x)
    check(abs(a.redComponent-b.redComponent)<0.02 && abs(a.greenComponent-b.greenComponent)<0.02 && abs(a.blueComponent-b.blueComponent)<0.02,"remaining amount must not shift or compress gradient")
    check(abs(b.greenComponent-c.greenComponent)<0.02,"gradient stays fixed across full and partial tracks")
}
check(color(low,90).alphaComponent<0.02 && color(high,90).alphaComponent>0.98,"only right side disappears")
check(color(empty,12).alphaComponent<0.02,"zero is empty")
check(abs(color(full,24).greenComponent-color(full,150).greenComponent)>0.03,"fixture is a real gradient")
if let path=ProcessInfo.processInfo.environment["USAGE_GRADIENT_TEST_OUTPUT"] {
    let root=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    for (name,bitmap) in [("25",low),("75",high),("100",full)] { try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("gradient-"+name+".png")) }
}
print("PASS rendered gradient: full-track coordinates stable at 25/75/100 percent, right-only clipping, zero hidden")

}
