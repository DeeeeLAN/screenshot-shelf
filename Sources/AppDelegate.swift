import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let shelf = ShelfController()
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var outsideMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var scanning = false
    private var scanGeneration = 0
    private var lastFingerprint = ""
    private var hotKeyStatus: OSStatus = noErr
    private let holdGesture = HoldGesture()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Screenshot Shelf")
            button.image?.isTemplate = true
            button.toolTip = "Hold ⌘⇧S for screenshots · Click for settings"
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        shelf.onSettings = { [weak self] button in self?.settingsMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button) }
        shelf.onRefresh = { [weak self] in self?.refresh(force: true) }
        shelf.onClose = { [weak self] in self?.stopMonitoring() }
        holdGesture.onPress = { [weak self] in self?.showShelf() }
        holdGesture.onRelease = { [weak self] in self?.shelf.hide() }
        registerHotKey()
        if CommandLine.arguments.contains("--enable-login") { enableLogin() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let button = statusItem.button { statusClicked(button) }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        stopMonitoring()
        holdGesture.release()
    }

    private func registerHotKey() {
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x53534846, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            if GetEventKind(event) == UInt32(kEventHotKeyPressed) { delegate.holdGesture.press() }
            else { delegate.holdGesture.release() }
            return noErr
        }, types.count, &types, pointer, &eventHandler)
        hotKeyStatus = handlerStatus
        if handlerStatus == noErr {
            hotKeyStatus = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x53534846, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
        }
        UserDefaults.standard.set(hotKeyStatus, forKey: "lastShortcutRegistrationStatus")
        NSLog("Screenshot Shelf: global shortcut registration status = %d", hotKeyStatus)
        if hotKeyStatus != noErr {
            statusItem.button?.toolTip = "Screenshot Shelf — ⌘⇧S is unavailable"
            DispatchQueue.main.async {
                self.showAlert("Couldn’t register ⌘⇧S", "Screenshot Shelf is available from its menu bar icon. Another app may already use this shortcut. Free up ⌘⇧S, then choose Retry Shortcut in Settings. (macOS status \(self.hotKeyStatus))")
            }
        }
    }

    private func showShelf(anchor: NSPoint? = nil) {
        shelf.show(near: anchor)
        refresh(force: true)
        startMonitoring()
    }

    private func refresh(force: Bool = false) {
        guard !scanning, !shelf.isDragging else { return }
        scanning = true
        let folder = ScreenshotStore.folder
        let generation = scanGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let scan = ScreenshotStore.scan(folder: folder)
            DispatchQueue.main.async {
                self.scanning = false
                guard generation == self.scanGeneration else { self.refresh(force: true); return }
                let fingerprint = scan.folder.path + (scan.error ?? "") + scan.screenshots.map { $0.revision + String($0.thumbnail != nil) }.joined(separator: "|")
                if !self.shelf.isDragging, force || fingerprint != self.lastFingerprint {
                    self.lastFingerprint = fingerprint
                    self.shelf.render(scan)
                }
            }
        }
    }

    private func startMonitoring() {
        stopMonitoring()
        // Mouse-only monitors do not request Accessibility or Input Monitoring.
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.shelf.hide() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            if event.type == .keyDown {
                if let self, event.window === self.shelf.panel, self.shelf.panel.onKey?(event) == true { return nil }
                return event
            }
            if let self, event.window !== self.shelf.panel, event.window !== self.statusItem.button?.window { self.shelf.hide() }
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func stopMonitoring() {
        timer?.invalidate(); timer = nil
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor); self.outsideMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        shelf.hide()
        settingsMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }

    private func settingsMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            return item
        }
        let heading = NSMenuItem(title: "Hold ⌘⇧S for screenshots", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        _ = add("Choose Screenshot Folder…", #selector(chooseFolder))
        _ = add("Use macOS Screenshot Folder", #selector(resetFolder))
        _ = add("Open Screenshot Folder", #selector(openFolder))
        menu.addItem(.separator())
        let login = add("Launch at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if SMAppService.mainApp.status == .requiresApproval {
            _ = add("Approve in Login Items…", #selector(openLoginSettings))
        }
        if hotKeyStatus != noErr { _ = add("Retry Shortcut", #selector(retryShortcut)) }
        menu.addItem(.separator())
        _ = add("Quit Screenshot Shelf", #selector(quit))
        return menu
    }

    @objc private func chooseFolder() {
        shelf.hide()
        NSApp.activate(ignoringOtherApps: true)
        let picker = NSOpenPanel()
        picker.title = "Choose your screenshot folder"
        picker.message = "Screenshot Shelf shows the most recent screenshots in this folder."
        picker.prompt = "Use Folder"
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = false
        picker.directoryURL = ScreenshotStore.folder
        if picker.runModal() == .OK, let url = picker.url {
            UserDefaults.standard.set(url.path, forKey: "screenshotFolder")
            scanGeneration += 1
            lastFingerprint = ""
        }
        refresh(force: true)
    }
    @objc private func resetFolder() {
        UserDefaults.standard.removeObject(forKey: "screenshotFolder")
        scanGeneration += 1
        refresh(force: true)
    }
    @objc private func openFolder() { NSWorkspace.shared.open(ScreenshotStore.folder) }
    @objc private func retryShortcut() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
        registerHotKey()
    }
    private func enableLogin() {
        guard SMAppService.mainApp.status != .enabled else { return }
        do { try SMAppService.mainApp.register() }
        catch { showAlert("Couldn’t enable Launch at Login", error.localizedDescription) }
    }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else { try SMAppService.mainApp.register() }
        } catch { showAlert("Couldn’t change Launch at Login", error.localizedDescription) }
    }
    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func showAlert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
