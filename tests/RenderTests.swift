@MainActor
func renderCases(to directory: String) throws {
    for scale in [1.0, 2.0] {
        for (name, remaining) in [("full", Double(100)), ("empty", Double(0)), ("unknown", Double?.none)] {
            for dark in [true, false] {
                let model = OverlayModel()
                model.snapshot = UsageSnapshot(remaining: remaining, detail: remaining == nil ? "Usage unavailable" : "7 days · 120 points", resetText: remaining == nil ? nil : "7d")
                model.isDarkBackground = dark
                model.connectionState = remaining == nil ? .disconnected : .connected
                let content = UsageEdgeTabView(model: model).content
                    .background(dark ? Color.black : Color.white)
                    .overlay(alignment: .topTrailing) { UsageEdgeTabView(model: model).statusAccessory }
                let renderer = ImageRenderer(content: content)
                renderer.scale = scale
                renderer.proposedSize = ProposedViewSize(width: 328, height: 74)
                guard let image = renderer.cgImage,
                      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("render failed") }
                try data.write(to: URL(fileURLWithPath: directory + "/\(name)-\(dark ? "dark" : "light")-\(Int(scale))x.png"))
            }
        }
    }
}
try MainActor.assumeIsolated { try renderCases(to: CommandLine.arguments[1]) }
print("PASS: 12 full/zero/unknown, light/dark, 1x/2x renders")
