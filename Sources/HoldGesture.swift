import AppKit
import Carbon

/// Keeps a single press active until any member of the shortcut is released.
/// The timer also runs during AppKit drag/menu tracking, when Carbon delivery
/// may be delayed. Only this shortcut's current state is sampled, while held.
final class HoldGesture {
    struct Keys {
        var command: Bool
        var shift: Bool
        var s: Bool
        var allDown: Bool { command && shift && s }
    }

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    private(set) var isPressed = false
    private var timer: Timer?
    private let readKeys: () -> Keys

    init(readKeys: @escaping () -> Keys = {
        let flags = NSEvent.modifierFlags
        return Keys(command: flags.contains(.command), shift: flags.contains(.shift),
                    s: CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_ANSI_S)))
    }) {
        self.readKeys = readKeys
    }

    func press() {
        guard !isPressed else { return } // Ignore repeated key-down events.
        isPressed = true
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.checkForRelease() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        onPress?()
    }

    func release() {
        guard isPressed else { return }
        isPressed = false
        timer?.invalidate()
        timer = nil
        onRelease?()
    }

    func checkForRelease() {
        if isPressed && !readKeys().allDown { release() }
    }

    deinit { timer?.invalidate() }
}
