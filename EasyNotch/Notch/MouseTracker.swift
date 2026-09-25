import AppKit

/// Watches the mouse system-wide and reports pointer moves and clicks in global screen
/// coordinates. Event-driven, so it costs nothing while the mouse is still. Watching mouse
/// events needs no permission; only keyboard monitoring would.
final class MouseTracker {
    var onMove: ((CGPoint) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?

    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown]

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
        if event.type == .mouseMoved {
            onMove?(location)
        } else {
            onMouseDown?(location)
        }
    }
}
