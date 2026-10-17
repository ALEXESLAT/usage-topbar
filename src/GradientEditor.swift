import SwiftUI
import AppKit

extension ProgressGradientStop {
    var color:Color { Color(.sRGB,red:red,green:green,blue:blue,opacity:alpha) }
}
extension ProgressGradientSettings {
    func gradient() -> LinearGradient {
        return LinearGradient(stops:orderedStops.map { Gradient.Stop(color:$0.color,location:$0.location) },startPoint:.leading,endPoint:.trailing)
    }
}

/// The gradient uses full-track coordinates; only its reveal mask changes.
struct QuotaGradientFill:View {
    let settings:ProgressGradientSettings
    let fraction:Double
    var body:some View {
        GeometryReader { geometry in
            Capsule().fill(settings.gradient())
                .mask(alignment:.leading) { Capsule().frame(width:geometry.size.width*max(0,min(1,fraction))) }
        }
    }
}

private struct GradientStopButtonStyle:ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.system(size:16,weight:.medium))
            .frame(width:30,height:30)
            .background(Color.primary.opacity(configuration.isPressed ? 0.15:0.07),in:RoundedRectangle(cornerRadius:6))
            .contentShape(RoundedRectangle(cornerRadius:6))
            .opacity(enabled ? 1:0.35)
    }
}

private struct ProgressGradientEditorView:View {
    @ObservedObject var session:ProgressGradientSession
    @State private var selected:UUID
    let save:()->Void
    let cancel:()->Void
    init(session:ProgressGradientSession,save:@escaping()->Void,cancel:@escaping()->Void) {
        self.session=session;self.save=save;self.cancel=cancel
        _selected=State(initialValue:session.draft.stops[0].id)
    }
    private var stop:ProgressGradientStop { session.draft.stops.first { $0.id==selected } ?? session.draft.stops[0] }
    private func channelColor(_ color:Color) {
        guard let value=NSColor(color).usingColorSpace(.sRGB) else { return }
        let id=stop.id
        session.edit { $0.color(id,red:value.redComponent,green:value.greenComponent,blue:value.blueComponent,alpha:value.alphaComponent) }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                GeometryReader { proxy in
                    ZStack(alignment:.leading) {
                        Capsule().fill(Color.secondary.opacity(0.13))
                        QuotaGradientFill(settings:session.draft,fraction:0.6)
                    }
                }.frame(height:6)
                Text("60%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment:.topLeading) {
                    Canvas { context,size in
                        let tile:CGFloat=8
                        for y in 0..<3 { for x in 0..<Int(size.width/tile)+1 {
                            context.fill(Path(CGRect(x:CGFloat(x)*tile,y:CGFloat(y)*tile,width:tile,height:tile)),with:.color((x+y)%2==0 ? .gray.opacity(0.25):.white.opacity(0.65)))
                        } }
                    }.frame(height:22).clipShape(RoundedRectangle(cornerRadius:5))
                    RoundedRectangle(cornerRadius:5).fill(session.draft.gradient()).frame(height:22)
                    ForEach(session.draft.stops) { item in
                        Button { selected=item.id } label: {
                            RoundedRectangle(cornerRadius:3).fill(item.color)
                                .overlay(RoundedRectangle(cornerRadius:3).stroke(selected==item.id ? Color.accentColor:Color.primary.opacity(0.5),lineWidth:selected==item.id ? 3:1))
                                .frame(width:14,height:18)
                        }
                        .buttonStyle(.plain)
                        .position(x:8+(proxy.size.width-16)*item.location,y:36)
                        .accessibilityLabel("色标 \(Int(item.location*100))%")
                        .simultaneousGesture(DragGesture(minimumDistance:1,coordinateSpace:.named("gradientTrack")).onChanged { value in
                            selected=item.id;session.edit { $0.move(item.id,to:Double((value.location.x-8)/(proxy.size.width-16))) }
                        })
                    }
                }.coordinateSpace(name:"gradientTrack")
            }.frame(height:48)
            HStack {
                Button { session.edit { settings in if let id=settings.add() { selected=id } } } label: { Image(systemName:"plus") }.buttonStyle(GradientStopButtonStyle()).disabled(session.draft.stops.count>=8).help("添加色标").accessibilityLabel("添加色标")
                Button { let id=stop.id;session.edit { $0.remove(id) };selected=session.draft.stops[0].id } label: { Image(systemName:"minus") }.buttonStyle(GradientStopButtonStyle()).disabled(session.draft.stops.count<=2).help("删除色标").accessibilityLabel("删除色标")
                Spacer()
                Text("\(session.draft.stops.count) / 8").font(.caption).foregroundStyle(.secondary)
            }
            ColorPicker("颜色",selection:Binding(get:{ stop.color },set:channelColor),supportsOpacity:true)
            HStack {
                Text("不透明度").frame(width:64,alignment:.leading)
                Slider(value:Binding(get:{ stop.alpha },set:{ value in let s=stop;session.edit { $0.color(s.id,red:s.red,green:s.green,blue:s.blue,alpha:value) } }),in:0...1)
                Text("\(Int((stop.alpha*100).rounded()))%").monospacedDigit().frame(width:40,alignment:.trailing)
            }
            HStack {
                Text("位置").frame(width:64,alignment:.leading)
                Slider(value:Binding(get:{ stop.location },set:{ value in let id=stop.id;session.edit { $0.move(id,to:value) } }),in:0...1)
                Text("\(Int((stop.location*100).rounded()))%").monospacedDigit().frame(width:40,alignment:.trailing)
            }
            if let error=session.error { Text(error).font(.caption).foregroundStyle(.red) }
            Divider()
            HStack {
                Button("默认") { session.reset();selected=session.draft.stops[0].id }
                Button(session.previewEnabled ? "结束预览":"预览") { session.setPreview(!session.previewEnabled) }.help("临时应用到主浮窗，确认后保存；取消或关闭会恢复原设置")
                Spacer()
                Button("取消",action:cancel).keyboardShortcut(.cancelAction)
                Button("确认",action:save).keyboardShortcut(.defaultAction)
            }
        }.padding(18).frame(width:440)
    }
}

final class ProgressGradientEditorController:NSObject,NSWindowDelegate {
    private var window:NSWindow?
    private var session:ProgressGradientSession?
    private let model:OverlayModel
    private let preferences:ProgressGradientPreferences
    init(model:OverlayModel,preferences:ProgressGradientPreferences) { self.model=model;self.preferences=preferences }
    func show() {
        let window=prepareWindow()
        NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil)
    }
    // Creating the editor has no activation or presentation side effects.
    func prepareWindow() -> NSWindow {
        if let window { return window }
        let session=ProgressGradientSession(original:model.progressGradient,preview:{ [weak model] settings in model?.progressGradient=settings },persist:{ [preferences] in preferences.save($0) })
        self.session=session
        let view=ProgressGradientEditorView(session:session,save:{ [weak self,weak session] in
            if session?.save()==true { self?.window?.close() }
        },cancel:{ [weak self] in self?.window?.close() })
        let host=NSHostingView(rootView:view)
        let w=NSWindow(contentRect:CGRect(x:0,y:0,width:520,height:440),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        w.title=AppVariant.isTesting ? "渐变设置 · 测试版" : "渐变设置";w.contentView=host;w.setContentSize(host.fittingSize);w.isReleasedWhenClosed=false;w.delegate=self
        window=w;w.center();return w
    }
    func windowWillClose(_ notification:Notification) { session?.cancel();session=nil;window=nil }
}
