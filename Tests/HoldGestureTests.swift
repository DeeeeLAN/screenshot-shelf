import AppKit

@main
struct HoldGestureTests {
    static func main() {
        _ = NSApplication.shared
        var keys = HoldGesture.Keys(command: true, shift: true, s: true)
        let gesture = HoldGesture(readKeys: { keys })
        let shelf = ShelfController()
        var opens = 0
        var closes = 0
        gesture.onPress = { opens += 1; shelf.show() }
        gesture.onRelease = { closes += 1; shelf.hide() }

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            print("PASS: " + message)
        }
        gesture.press()
        check(shelf.panel.isVisible, "Press displays the shelf")
        gesture.press()
        gesture.checkForRelease()
        check(opens == 1 && shelf.panel.isVisible, "Holding and auto-repeat keep the same shelf open")
        gesture.release()
        check(!shelf.panel.isVisible && closes == 1, "Key release immediately hides the shelf")
        gesture.release()
        check(closes == 1, "Duplicate release events do nothing")

        for key in ["Command", "Shift", "S"] {
            keys = .init(command: true, shift: true, s: true)
            gesture.press()
            if key == "Command" { keys.command = false }
            if key == "Shift" { keys.shift = false }
            if key == "S" { keys.s = false }
            gesture.checkForRelease()
            check(!shelf.panel.isVisible && !gesture.isPressed, "Releasing \(key) independently closes the shelf")
        }

        keys = .init(command: true, shift: true, s: true)
        gesture.press()
        shelf.isDragging = true
        keys.s = false
        let deadline = Date().addingTimeInterval(0.5)
        while gesture.isPressed && Date() < deadline {
            _ = RunLoop.main.run(mode: .eventTracking, before: deadline)
        }
        check(!shelf.panel.isVisible && shelf.isDragging, "Release hides the panel without terminating the drag")
        shelf.isDragging = false
        keys.s = true
        gesture.press()
        shelf.hide() // Escape/click-outside dismissal.
        let countBeforeRepeat = opens
        gesture.press()
        check(!shelf.panel.isVisible && opens == countBeforeRepeat, "Dismissal does not reopen the shelf on auto-repeat")
        gesture.release()
        gesture.press()
        check(shelf.panel.isVisible, "A new press works after release")
        gesture.release()
    }
}
