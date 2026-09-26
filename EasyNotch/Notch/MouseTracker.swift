import AppKit

/// Watches the mouse system-wide and reports pointer moves, clicks, and drags in global screen
/// coordinates. Event-driven, so it costs nothing while the mouse is still. Watching mouse
/// events needs no permission; only keyboard monitoring would.
final class MouseTracker {
    var onMove: ((CGPoint) -> Void)?
    /// A left click.
    var onMouseDown: ((CGPoint) -> Void)?
    /// A right click (or a Control-click).
    var onRightMouseDown: ((CGPoint) -> Void)?
    /// The mouse moved with the button held. The flag says whether files are being dragged.
    var onDrag: ((CGPoint, Bool) -> Void)?

    private var monitors: [Any] = []
    private var dragDetector = FileDragDetector()
    private let dragPasteboard = NSPasteboard(name: .drag)

    func start() {
        guard monitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged, .leftMouseUp,
        ]

        // Events headed to other apps (most of the time).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        // Events headed to EasyNotch's own windows (the open notch, Settings).
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .mouseMoved:
            onMove?(location)
        case .leftMouseDown:
            dragDetector.mouseDown(changeCount: dragPasteboard.changeCount)
            if event.modifierFlags.contains(.control) {
                onRightMouseDown?(location)
            } else {
                onMouseDown?(location)
            }
        case .rightMouseDown:
            onRightMouseDown?(location)
        case .leftMouseDragged:
            let pasteboard = dragPasteboard
            let carryingFiles = dragDetector.mouseDragged(
                changeCount: { pasteboard.changeCount },
                hasFiles: { pasteboard.types?.contains(.fileURL) == true }
            )
            onDrag?(location, carryingFiles)
        case .leftMouseUp:
            dragDetector.mouseUp()
        default:
            break
        }
    }
}
