import AppKit
import Carbon

@main
struct HotKeyProbe {
    static func main() {
        _ = NSApplication.shared
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x54455354, id: 9), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        print("Exclusive hotkey probe status: \(status) (a conflict means another process owns ⌘⇧S)")
        if let ref { UnregisterEventHotKey(ref) }
    }
}
