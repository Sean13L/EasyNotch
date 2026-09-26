import AppKit
import QuickLookUI

/// Things you can do with shelf files.
///
/// Actions that show system windows (AirDrop, Quick Look) first make EasyNotch the active app.
/// Agent apps are never active on their own, and macOS won't show those windows for an app
/// that isn't.
enum ShelfActions {
    private static let quickLook = QuickLookController()

    static func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        guard service.canPerform(withItems: urls) else {
            Log.shelf.error("AirDrop isn't available (is Wi-Fi or Bluetooth off?)")
            return
        }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    static func open(_ urls: [URL]) {
        urls.forEach { NSWorkspace.shared.open($0) }
    }

    static func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Puts the files on the clipboard, so ⌘V pastes them in Finder, Mail, Slack, and so on.
    static func copy(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    static func quickLook(_ urls: [URL], startingAt index: Int = 0) {
        quickLook.show(urls, startingAt: index)
    }
}

/// Feeds files to the system Quick Look window.
private final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    private var urls: [URL] = []

    func show(_ urls: [URL], startingAt index: Int) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        NSApp.activate()
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = min(index, urls.count - 1)
        panel.makeKeyAndOrderFront(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }
}
