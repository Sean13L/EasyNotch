import AppKit
import SwiftUI

/// Shows the Settings window, creating it the first time. It also decides when the notch
/// should show a live preview: only while this window is in front and the Size pane is
/// selected. The Size pane picks which shape to preview.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Told whenever the notch preview changes; `nil` means no preview.
    var onPreviewChange: ((SizePreview?) -> Void)?

    private let settings: AppSettings
    private let nowPlaying: NowPlayingService
    private var window: NSWindow?
    private var selectedPane: SettingsPane = .general
    private var sizePreview: SizePreview = .expanded

    init(settings: AppSettings, nowPlaying: NowPlayingService) {
        self.settings = settings
        self.nowPlaying = nowPlaying
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
        let isPreviewing = window?.isKeyWindow == true && selectedPane == .size
        onPreviewChange?(isPreviewing ? sizePreview : nil)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            settings: settings,
            nowPlaying: nowPlaying,
            onPaneChange: { [weak self] pane in
                self?.selectedPane = pane
                self?.updatePreview()
            },
            onSizePreviewChange: { [weak self] preview in
                self?.sizePreview = preview
                self?.updatePreview()
            }
        )
        let window = SettingsWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "EasyNotch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 700, height: 480))
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
