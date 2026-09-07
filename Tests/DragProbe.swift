import AppKit

final class DropProbe: NSView {
    let result: URL
    var sourceHidden: () -> Bool = { false }
    init(frame: NSRect, result: URL) {
        self.result = result
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        layer?.cornerRadius = 14
        let label = NSTextField(labelWithString: "Drop the test screenshot here")
        label.frame = NSRect(x: 18, y: 125, width: 260, height: 30)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let output: [String: Any] = ["fileURLReceived": urls.count == 1, "originalStillExists": urls.first.map { FileManager.default.fileExists(atPath: $0.path) } ?? false, "copyOnly": sender.draggingSourceOperationMask == .copy, "sourceHiddenDuringDrag": sourceHidden()]
        if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: result) }
        return urls.count == 1
    }
}

@main
struct DragProbe {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let build = Bundle.main.bundleURL.deletingLastPathComponent()
        let file = build.appendingPathComponent("Screenshot test-fixture.png")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320, pixelsHigh: 180, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: file)
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Screenshot Shelf Drag Test"
        window.isReleasedWhenClosed = false
        let root = FlippedView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        let card = ScreenshotCard(screenshot: Screenshot(url: file, date: Date(), thumbnail: NSImage(contentsOf: file), dimensions: "320 × 180", revision: "test"), frame: NSRect(x: 24, y: 90, width: 192, height: 142))
        card.onDragStart = {
            let timer = Timer(timeInterval: 0.02, repeats: false) { _ in card.isHidden = true }
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.main.add(timer, forMode: .eventTracking)
        }
        root.addSubview(card)
        let drop = DropProbe(frame: NSRect(x: 280, y: 35, width: 330, height: 290), result: build.appendingPathComponent("drag-result.json"))
        drop.sourceHidden = { card.isHidden }
        root.addSubview(drop)
        window.contentView = root
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
