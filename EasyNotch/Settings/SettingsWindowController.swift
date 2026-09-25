import AppKit
import SwiftUI

/// Shows the Settings window, creating it the first time. It also decides when the notch
/// should be held open as a live preview: only while this window is in front and the Size
/// pane is selected.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Told whenever the live notch preview should start (true) or stop (false).
    var onPreviewChange: ((Bool) -> Void)?

    private let settings: AppSettings
    private var window: NSWindow?
    private var selectedPane: SettingsPane = .behavior

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Agent apps are never "active" on their own; without this the window opens
        // behind whatever app you're using.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        Log.settings.debug("Settings window shown")
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        updatePreview()
    }

    func windowDidResignKey(_ notification: Notification) {
        updatePreview()
    }

    // MARK: - Private

    private func updatePreview() {
        onPreviewChange?(window?.isKeyWindow == true && selectedPane == .size)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(settings: settings) { [weak self] pane in
            self?.selectedPane = pane
            self?.updatePreview()
        }
        let window = SettingsWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "EasyNotch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 640, height: 420))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("SettingsWindow")  // remembers where you put it
        return window
    }
}

/// Adds ⌘W to close. Regular apps get it from their menu bar, but agent apps have none.
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
