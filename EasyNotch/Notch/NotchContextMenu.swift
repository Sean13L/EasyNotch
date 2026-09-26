import AppKit

/// The small menu that appears when you right-click the closed notch.
enum NotchContextMenu {
    static func show(at point: CGPoint, onShowSettings: @escaping () -> Void) {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…", action: #selector(MenuAction.run), keyEquivalent: "")
        let action = MenuAction(onShowSettings)
        settings.target = action
        settings.representedObject = action  // menu items don't keep their target alive
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit EasyNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)

        // With no view to attach to, the point is in screen coordinates.
        menu.popUp(positioning: nil, at: point, in: nil)
    }
}

/// Runs a closure when its menu item is chosen.
private final class MenuAction: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func run() {
        handler()
    }
}
