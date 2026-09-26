import AppKit
import SwiftUI

/// Starts file drags with AppKit and reports whether they were dropped somewhere.
///
/// SwiftUI's own dragging can't say whether a drop happened, which "Remove files after dragging
/// them out" needs. It also only carries one item at a time.
class FileDragSourceView: NSView, NSDraggingSource {
    /// Called when a drag ends, with the dragged files and whether they landed somewhere else.
    var onDragEnded: (([URL], Bool) -> Void)?

    private var draggedURLs: [URL] = []

    func startDrag(with urls: [URL], event: NSEvent) {
        guard !urls.isEmpty else { return }
        draggedURLs = urls
        // A small fanned-out stack of file icons follows the pointer.
        let origin = convert(event.locationInWindow, from: nil)
        let items = urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            item.setDraggingFrame(
                NSRect(x: origin.x - 16 + offset, y: origin.y - 16 - offset, width: 32, height: 32),
                contents: NSWorkspace.shared.icon(forFile: url.path)
            )
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Dropping back onto the notch itself doesn't count as "dragged out".
        let droppedOnNotch = window?.frame.contains(screenPoint) == true
        onDragEnded?(draggedURLs, operation != [] && !droppedOnNotch)
        draggedURLs = []
    }
}

// MARK: - Drag-all handle

/// A handle you drag to carry several files at once, e.g. into an upload field.
struct FileDragHandle: NSViewRepresentable {
    let urls: [URL]
    let onDragEnded: ([URL], Bool) -> Void

    func makeNSView(context: Context) -> FileDragHandleView {
        FileDragHandleView()
    }

    func updateNSView(_ view: FileDragHandleView, context: Context) {
        view.urls = urls
        view.onDragEnded = onDragEnded
    }
}

final class FileDragHandleView: FileDragSourceView {
    var urls: [URL] = [] {
        didSet { toolTip = urls.count == 1 ? "Drag this file" : "Drag all \(urls.count) files" }
    }

    private let icon = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "Drag all")
        icon.contentTintColor = .white
        icon.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("FileDragHandleView is only created in code")
    }

    /// Respond to the first click even though EasyNotch isn't the active app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Handled here (instead of passing it on) so that mouseDragged arrives.
    }

    override func mouseDragged(with event: NSEvent) {
        startDrag(with: urls, event: event)
    }
}

// MARK: - Dragging tiles

/// Lets a SwiftUI gesture start an AppKit drag. Put a `FileDragAnchor` behind the view, then call
/// `start(_:)` from its drag gesture.
final class FileDragStarter {
    fileprivate weak var anchor: FileDragSourceView?

    func start(_ urls: [URL]) {
        // The mouse event SwiftUI is handling right now carries the drag's starting point.
        guard let anchor, let event = NSApp.currentEvent,
              event.type == .leftMouseDragged || event.type == .leftMouseDown
        else { return }
        anchor.startDrag(with: urls, event: event)
    }
}

/// An invisible view behind a tile that owns its drags. It lets clicks pass through, so
/// SwiftUI still handles selection, double-click, and right-click.
struct FileDragAnchor: NSViewRepresentable {
    let starter: FileDragStarter
    let onDragEnded: ([URL], Bool) -> Void

    func makeNSView(context: Context) -> FileDragAnchorView {
        FileDragAnchorView()
    }

    func updateNSView(_ view: FileDragAnchorView, context: Context) {
        starter.anchor = view
        view.onDragEnded = onDragEnded
    }
}

final class FileDragAnchorView: FileDragSourceView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
