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
                let renderer = ImageRenderer(content: content)
                renderer.scale = scale
                renderer.proposedSize = ProposedViewSize(width: OverlayDimensions.width, height: 74)
                guard let image = renderer.cgImage,
                      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("render failed") }
                try data.write(to: URL(fileURLWithPath: directory + "/\(name)-\(dark ? "dark" : "light")-\(Int(scale))x.png"))
            }
        }
    }
}
try MainActor.assumeIsolated { try renderCases(to: CommandLine.arguments[1]) }
print("PASS: 12 full/zero/unknown, light/dark, 1x/2x renders")

// Render the actual AppKit menu image at both backing scales and appearances.
for scale in [1, 2] {
    for dark in [false, true] {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 18 * scale, pixelsHigh: 18 * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: 18, height: 18)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: 18, height: 18)
        CodexMark.statusImage.draw(in: rect)
        (dark ? NSColor.white : NSColor.black).setFill()
        rect.fill(using: .sourceIn)
        (dark ? NSColor.black : NSColor.white).setFill()
        rect.fill(using: .destinationOver)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/codex-menu-\(dark ? "dark" : "light")-\(scale)x.png"))
    }
}
print("PASS: 4 Codex menu image renders, light/dark, 1x/2x")

try MainActor.assumeIsolated {
    let now = Date(timeIntervalSince1970: 1_791_534_998)
    for (name, offset) in [("five-days", Double(5 * 86400 + 3600)), ("hour-boundary", 86399), ("expired", -1)] {
        for dark in [true, false] {
            let model = OverlayModel()
            model.snapshot = UsageSnapshot(remaining: 33, detail: "", resetText: nil,
                                           resetsAt: now.timeIntervalSince1970 + offset,
                                           resetDetailSuffix: "0 points").refreshed(at: now)
            model.isDarkBackground = dark
            let content = UsageEdgeTabView(model: model).content
                .background(dark ? Color.black : Color.white)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: OverlayDimensions.width, height: 74)
            let image = renderer.cgImage!
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/reset-\(name)-\(dark ? "dark" : "light").png"))
        }
    }
}
print("PASS: 6 reset deadline renders, five-day/hour boundary/expired, light/dark")

try MainActor.assumeIsolated {
    let now = Date(timeIntervalSince1970: 1893456000)
    func cardRow(_ id: String, _ expiry: Any = NSNull()) -> [String: Any] {
        ["id": id, "status": "available", "resetType": "codexRateLimits", "expiresAt": expiry]
    }
    let cases: [(String, ResetCards?)] = [
        ("unknown", nil),
        ("zero", ResetCards.parse(["availableCount": 0, "credits": []])),
        ("one", ResetCards.parse(["availableCount": 1, "credits": [cardRow("1", 1894305600)]])),
        ("synthetic-three", ResetCards.parse(["availableCount": 3, "credits": [cardRow("1", 1894305600), cardRow("2", 1895169600), cardRow("3", 1896033600)]])),
        ("missing-expiry", ResetCards.parse(["availableCount": 3, "credits": NSNull()])),
        ("expired", ResetCards.parse(["availableCount": 1, "credits": [cardRow("1", 1)]])),
        ("no-expiry", ResetCards.parse(["availableCount": 1, "credits": [cardRow("1")]])),
        ("large", ResetCards.parse(["availableCount": 1000, "credits": NSNull()]))
    ]
    for (name, cards) in cases {
        for scale in [1.0, 2.0] {
        for dark in [false, true] {
            let model = OverlayModel()
            model.snapshot = UsageSnapshot(remaining: 31, detail: "", resetText: nil, resetsAt: 1893891600, resetDetailSuffix: "0 points", resetCards: cards).refreshed(at: now)
            model.isDarkBackground = dark
            let view = UsageEdgeTabView(model: model)
            let renderer = ImageRenderer(content: view.content.background(dark ? Color.black : Color.white))
            renderer.scale = scale
            renderer.proposedSize = ProposedViewSize(width: OverlayDimensions.width, height: 74)
            let image = renderer.cgImage!
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/cards-\(name)-\(dark ? "dark" : "light")-\(Int(scale))x.png"))
        }
        }
    }
}
print("PASS: 32 reset card renders, 1x/2x light/dark")

try MainActor.assumeIsolated {
    let cases: [(String, Double?, String, String?, Double, Double, Int?, GPTConnectionState)] = [
        ("normal", 22, "5d left · 0 points", "5d", 24576, 3072, 3, .connected),
        ("maximum", 100, "23h59m left · 1000000k points", "23h", 1e30, 1e30, 1000, .connected),
        ("single", 9, "99d23h left · 999.9k points", "99d", 999.4, 10737418240, 1, .checking),
        ("zero", 0, "<1m left · 0 points", "<1m", 0, 0, 0, .disconnected),
        ("unknown", nil, "Usage unavailable", nil, .nan, .infinity, nil, .disconnected)
    ]
    for (name, remaining, detail, reset, down, up, count, state) in cases {
        for width in [CGFloat(300), OverlayDimensions.width] {
            for scale in [1.0, 2.0] {
                for dark in [false, true] {
                    let model = OverlayModel()
                    model.snapshot = UsageSnapshot(remaining: remaining, detail: detail, resetText: reset)
                    model.snapshot.resetCardDisplay = ResetCardDisplay(count: count, expiryText: count == nil ? "Exp. —" : "Exp. 12/31", accessibilityText: "Synthetic layout fixture")
                    model.downloadBytesPerSecond = down
                    model.uploadBytesPerSecond = up
                    model.connectionState = state
                    model.isDarkBackground = dark
                    let view = UsageEdgeTabView(model: model, contentWidth: width)
                    let renderer = ImageRenderer(content: view.content.background(dark ? Color.black : Color.white))
                    renderer.scale = scale
                    renderer.proposedSize = ProposedViewSize(width: width, height: 74)
                    guard let image = renderer.cgImage else { fatalError("layout render failed") }
                    checkRenderSize(image, width: Int(width * scale), height: Int(74 * scale))
                    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/layout-\(name)-\(Int(width))-\(dark ? "dark" : "light")-\(Int(scale))x.png"))
                }
            }
        }
    }
}
func checkRenderSize(_ image: CGImage, width: Int, height: Int) {
    precondition(image.width == width && image.height == height, "layout escaped proposed width/height")
}
print("PASS: 40 layout stress renders: 300/308pt, 1x/2x, light/dark, normal/100%/long/zero/unknown")
