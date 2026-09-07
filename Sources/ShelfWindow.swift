import AppKit

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class ShelfPanel: NSPanel {
    var onKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if onKey?(event) != true { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKey?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class ScreenshotCard: NSView, NSDraggingSource {
    let screenshot: Screenshot
    var onSelect: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: ((NSDragOperation) -> Void)?
    var selected = false { didSet { needsDisplay = true } }
    private var hovering = false
    private var downPoint: NSPoint?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(screenshot: Screenshot, frame: NSRect) {
        self.screenshot = screenshot
        super.init(frame: frame)
        toolTip = screenshot.url.lastPathComponent + "\nDrag to another app · Double-click to open"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(screenshot.url.lastPathComponent)
        setAccessibilityHelp("Drag this screenshot into another app. Press Command C to copy, or Return to open.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        (hovering || selected ? NSColor.controlAccentColor.withAlphaComponent(0.09) : NSColor.controlBackgroundColor.withAlphaComponent(0.72)).setFill()
        box.fill()
        (selected ? NSColor.controlAccentColor : NSColor.separatorColor.withAlphaComponent(0.3)).setStroke()
        box.lineWidth = selected ? 2 : 0.7
        box.stroke()

        let preview = NSRect(x: 8, y: 8, width: bounds.width - 16, height: 88)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: preview, xRadius: 6, yRadius: 6).addClip()
        NSColor.quaternaryLabelColor.withAlphaComponent(0.10).setFill()
        preview.fill()
        if let image = screenshot.thumbnail, image.size.width > 0, image.size.height > 0 {
            let scale = min(preview.width / image.size.width, preview.height / image.size.height)
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let rect = NSRect(x: preview.midX - size.width / 2, y: preview.midY - size.height / 2, width: size.width, height: size.height)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        } else {
            NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?.draw(in: NSRect(x: preview.midX - 14, y: preview.midY - 14, width: 28, height: 28), from: .zero, operation: .sourceOver, fraction: 0.5, respectFlipped: true, hints: nil)
        }
        NSGraphicsContext.restoreGraphicsState()

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        drawText(formatter.string(from: screenshot.date), rect: NSRect(x: 10, y: 103, width: bounds.width - 20, height: 17), font: .systemFont(ofSize: 11, weight: .medium), color: .labelColor)
        drawText(screenshot.dimensions, rect: NSRect(x: 10, y: 120, width: bounds.width - 20, height: 14), font: .systemFont(ofSize: 10), color: .secondaryLabelColor)
    }

    private func drawText(_ text: String, rect: NSRect, font: NSFont, color: NSColor) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = convert(event.locationInWindow, from: nil)
        onSelect?()
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { NSWorkspace.shared.open(screenshot.url) }
    }
    override func mouseUp(with event: NSEvent) { downPoint = nil }
    override func mouseDragged(with event: NSEvent) {
        guard let downPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - downPoint.x, point.y - downPoint.y) > 4 else { return }
        self.downPoint = nil
        guard FileManager.default.fileExists(atPath: screenshot.url.path) else { NSSound.beep(); return }
        let item = NSDraggingItem(pasteboardWriter: screenshot.url as NSURL)
        item.setDraggingFrame(NSRect(x: 8, y: 8, width: bounds.width - 16, height: 88), contents: screenshot.thumbnail ?? NSWorkspace.shared.icon(forFile: screenshot.url.path))
        onDragStart?()
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { onDragEnd?(operation) }

    override func accessibilityPerformPress() -> Bool {
        onSelect?()
        window?.makeFirstResponder(self)
        return true
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        onSelect?()
        let menu = NSMenu()
        for (title, action) in [("Copy Screenshot", #selector(copyScreenshot)), ("Show in Finder", #selector(reveal)), ("Open", #selector(openScreenshot))] {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
        }
        return menu
    }
    @objc private func copyScreenshot() { ScreenshotCard.copy(screenshot) }
    @objc private func reveal() { NSWorkspace.shared.activateFileViewerSelecting([screenshot.url]) }
    @objc private func openScreenshot() { NSWorkspace.shared.open(screenshot.url) }
    static func copy(_ shot: Screenshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var objects: [NSPasteboardWriting] = [shot.url as NSURL]
        if let image = NSImage(contentsOf: shot.url) { objects.append(image) }
        pasteboard.writeObjects(objects)
    }
}

final class ShelfController: NSObject, NSWindowDelegate {
    let panel: ShelfPanel
    private let subtitle = NSTextField(labelWithString: "Your latest captures, ready to drag.")
    private let footer = NSTextField(labelWithString: "Hold ⌘⇧S  ·  Drag a screenshot  ·  Release to close")
    private let scrollView = NSScrollView()
    private let document = FlippedView()
    private var cards: [ScreenshotCard] = []
    private var selectedIndex = 0
    var isDragging = false
    var onSettings: ((NSButton) -> Void)?
    var onClose: (() -> Void)?
    var onRefresh: (() -> Void)?

    override init() {
        panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 552), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Screenshot Shelf"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onKey = { [weak self] event in self?.handleKey(event) ?? false }

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 640, height: 552))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true
        panel.contentView = effect
        let root = FlippedView(frame: effect.bounds)
        effect.addSubview(root)

        let title = NSTextField(labelWithString: "Screenshots")
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        title.frame = NSRect(x: 22, y: 17, width: 230, height: 28)
        root.addSubview(title)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 22, y: 47, width: 465, height: 18)
        root.addSubview(subtitle)

        let shortcut = NSTextField(labelWithString: "Hold ⌘⇧S")
        shortcut.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        shortcut.textColor = .secondaryLabelColor
        shortcut.alignment = .center
        shortcut.frame = NSRect(x: 468, y: 26, width: 105, height: 22)
        root.addSubview(shortcut)
        let settings = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!, target: self, action: #selector(settingsClicked(_:)))
        settings.isBordered = false
        settings.frame = NSRect(x: 582, y: 21, width: 34, height: 32)
        settings.toolTip = "Folder, launch at login, and quit"
        root.addSubview(settings)

        scrollView.frame = NSRect(x: 18, y: 80, width: 604, height: 426)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = document
        root.addSubview(scrollView)
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: 22, y: 522, width: 520, height: 16)
        root.addSubview(footer)
        let refresh = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh screenshots")!, target: self, action: #selector(refreshClicked))
        refresh.isBordered = false
        refresh.frame = NSRect(x: 586, y: 515, width: 28, height: 28)
        refresh.toolTip = "Refresh screenshots (⌘R)"
        root.addSubview(refresh)
    }

    func show(near anchor: NSPoint? = nil) {
        let point = anchor ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let size = panel.frame.size
        let x = min(max(point.x - size.width / 2, visible.minX), visible.maxX - size.width)
        let desiredY = anchor == nil ? point.y - size.height * 0.35 : point.y - size.height - 8
        let y = min(max(desiredY, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        select(0)
        document.scroll(.zero)
    }

    func hide() {
        // Keep the views alive so a file drag can finish after the panel hides.
        panel.orderOut(nil)
        onClose?()
    }
    func windowDidResignKey(_ notification: Notification) { if !isDragging { hide() } }

    func render(_ scan: ScreenshotScan) {
        guard !isDragging else { return }
        let selectedURL = cards.indices.contains(selectedIndex) ? cards[selectedIndex].screenshot.url : nil
        document.subviews.forEach { $0.removeFromSuperview() }
        cards.removeAll()
        subtitle.stringValue = "\(scan.screenshots.count) recent screenshot\(scan.screenshots.count == 1 ? "" : "s") · \(scan.folder.lastPathComponent)"
        subtitle.toolTip = scan.folder.path
        footer.stringValue = "Hold ⌘⇧S  ·  Drag a screenshot  ·  Release to close"
        let rows = max(1, Int(ceil(Double(scan.screenshots.count) / 3.0)))
        document.frame = NSRect(x: 0, y: 0, width: 604, height: max(426, CGFloat(rows) * 152))
        if scan.screenshots.isEmpty {
            let label = NSTextField(wrappingLabelWithString: scan.error == nil ? "No screenshots here yet\n\nTake one with ⌘⇧4, then open the shelf.\nYou can choose a different folder in Settings." : "Can’t read your screenshot folder\n\n\(scan.error!)\n\nChoose the folder from Settings to grant access.")
            label.alignment = .center
            label.font = .systemFont(ofSize: 14)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: 65, y: 120, width: 474, height: 180)
            document.addSubview(label)
            return
        }
        for (index, shot) in scan.screenshots.enumerated() {
            let frame = NSRect(x: CGFloat(index % 3) * 202 + 2, y: CGFloat(index / 3) * 152 + 2, width: 192, height: 142)
            let card = ScreenshotCard(screenshot: shot, frame: frame)
            card.onSelect = { [weak self] in self?.select(index) }
            card.onDragStart = { [weak self] in self?.isDragging = true }
            card.onDragEnd = { [weak self] operation in
                guard let self else { return }
                self.isDragging = false
                if !operation.isEmpty { self.hide() }
            }
            document.addSubview(card)
            cards.append(card)
        }
        select(cards.firstIndex(where: { $0.screenshot.url == selectedURL }) ?? 0, scroll: false)
    }

    private func select(_ index: Int, scroll: Bool = true) {
        guard cards.indices.contains(index) else { return }
        selectedIndex = index
        for (i, card) in cards.enumerated() { card.selected = i == index }
        panel.makeFirstResponder(cards[index])
        if scroll { cards[index].scrollToVisible(cards[index].bounds) }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        if event.keyCode == 53 { hide(); return true }
        if command && event.charactersIgnoringModifiers?.lowercased() == "r" { onRefresh?(); return true }
        guard !cards.isEmpty else { return false }
        if command && event.charactersIgnoringModifiers?.lowercased() == "c" {
            ScreenshotCard.copy(cards[selectedIndex].screenshot)
            footer.stringValue = "Copied. Paste into another app with ⌘V."
            return true
        }
        switch event.keyCode {
        case 123: select(max(0, selectedIndex - 1))
        case 124: select(min(cards.count - 1, selectedIndex + 1))
        case 125: select(min(cards.count - 1, selectedIndex + 3))
        case 126: select(max(0, selectedIndex - 3))
        case 36: NSWorkspace.shared.open(cards[selectedIndex].screenshot.url); hide()
        default: return false
        }
        return true
    }
    @objc private func settingsClicked(_ sender: NSButton) { onSettings?(sender) }
    @objc private func refreshClicked() { onRefresh?() }
}
