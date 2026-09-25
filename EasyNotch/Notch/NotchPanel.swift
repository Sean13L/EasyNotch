import AppKit
import SwiftUI

/// The borderless window that sits over the notch. It floats above the menu bar, appears
/// on every Space (including full-screen apps), and never takes focus from the app you're
/// using.
final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // SwiftUI draws the shadow around the notch shape instead
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true  // while closed, clicks fall through to the menu bar
    }

    // Keyboard focus stays with whatever app you're using.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts SwiftUI inside the panel. Accepting the "first mouse" makes a button respond to
/// the first click even though EasyNotch is never the active app.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
