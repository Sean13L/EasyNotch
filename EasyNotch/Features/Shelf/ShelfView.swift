import SwiftUI

/// The Shelf tab in the open notch: an AirDrop tile on the left, and on the right the files
/// you've dropped in, with actions above them. Dropping files anywhere on the open notch adds
/// them (see `ExpandedView`); dropping on the AirDrop tile sends them straight away.
struct ShelfView: View {
    @Environment(ShelfStore.self) private var shelf

    @State private var selection: Set<ShelfItem.ID> = []

    /// The selected files, or all of them when nothing is selected.
    private var actionURLs: [URL] {
        let selected = shelf.urls(for: selection)
        return selected.isEmpty ? shelf.availableURLs : selected
    }

    var body: some View {
        HStack(spacing: 14) {
            AirDropTile(urls: actionURLs)

            VStack(alignment: .leading, spacing: 8) {
                ShelfHeader(selection: $selection, actionURLs: actionURLs)
                if shelf.items.isEmpty {
                    EmptyDropZone(isTargeted: shelf.isDropTargeted)
                } else {
                    itemsRow
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(6)
                .opacity(shelf.isDropTargeted && !shelf.items.isEmpty ? 1 : 0)
        }
        // Find renamed, moved, or deleted files each time the tab appears.
        .onAppear { shelf.refresh() }
        .onChange(of: shelf.items) { _, items in
            selection.formIntersection(items.map(\.id))
        }
    }

    private var itemsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shelf.items) { item in
                    ShelfTile(item: item, selection: $selection)
                }
            }
        }
    }
}

/// One file on the shelf, with its click, drag, and right-click behavior.
private struct ShelfTile: View {
    let item: ShelfItem
    @Binding var selection: Set<ShelfItem.ID>

    @Environment(ShelfStore.self) private var shelf
    @State private var dragStarter = FileDragStarter()
    @State private var isDragging = false

    var body: some View {
        ShelfItemView(
            item: item,
            status: shelf.status(of: item),
            isSelected: selection.contains(item.id),
            thumbnails: shelf.thumbnails
        )
        .background(FileDragAnchor(starter: dragStarter) { urls, droppedElsewhere in
            isDragging = false
            if droppedElsewhere { shelf.finishedDraggingOut(urls) }
        })
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    guard !isDragging else { return }
                    isDragging = true
                    dragStarter.start(dragURLs)
                }
                .onEnded { _ in isDragging = false }
        )
        .onTapGesture(count: 2) {
            shelf.url(for: item).map { ShelfActions.open([$0]) }
        }
        .onTapGesture(perform: select)
        .contextMenu {
            ItemMenu(item: item, selection: $selection)
        }
    }

    /// Dragging a selected file carries the whole selection, like in Finder.
    private var dragURLs: [URL] {
        if selection.contains(item.id) { return shelf.urls(for: selection) }
        return shelf.url(for: item).map { [$0] } ?? []
    }

    /// Click selects just this file; ⌘-click adds it to (or removes it from) the selection.
    private func select() {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.remove(item.id) == nil { selection.insert(item.id) }
        } else {
            selection = selection == [item.id] ? [] : [item.id]
        }
    }
}

private struct ShelfHeader: View {
    @Binding var selection: Set<ShelfItem.ID>
    let actionURLs: [URL]

    @Environment(ShelfStore.self) private var shelf
    @State private var isConfirmingClear = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if !actionURLs.isEmpty {
                ShareLink(items: actionURLs) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .help("Share")
                Button { ShelfActions.copy(actionURLs) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy (then paste with ⌘V)")
                FileDragHandle(urls: actionURLs) { urls, droppedElsewhere in
                    if droppedElsewhere { shelf.finishedDraggingOut(urls) }
                }
                .frame(width: 20, height: 20)
            }
            if !shelf.items.isEmpty {
                clearButton
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .frame(height: 20)
    }

    private var title: String {
        let count = shelf.items.count
        if count == 0 { return "Shelf" }
        if !selection.isEmpty { return "\(selection.count) of \(count) selected" }
        return count == 1 ? "1 item" : "\(count) items"
    }

    /// Asks for a second click instead of a dialog (dialogs don't work well in the notch).
    @ViewBuilder private var clearButton: some View {
        if isConfirmingClear {
            Button("Clear all?") {
                shelf.removeAll()
                isConfirmingClear = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .task {
                try? await Task.sleep(for: .seconds(3))
                isConfirmingClear = false
            }
        } else {
            Button {
                if shelf.confirmsBeforeClearing {
                    isConfirmingClear = true
                } else {
                    shelf.removeAll()
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("Clear the shelf")
        }
    }
}

private struct ItemMenu: View {
    let item: ShelfItem
    @Binding var selection: Set<ShelfItem.ID>

    @Environment(ShelfStore.self) private var shelf

    /// Right-clicking a selected file acts on the whole selection, like in Finder.
    private var targetIDs: Set<ShelfItem.ID> {
        selection.contains(item.id) ? selection : [item.id]
    }

    var body: some View {
        let urls = shelf.urls(for: targetIDs)
        if shelf.status(of: item) == .noAccess {
            Button("Allow Access in System Settings…") {
                NSWorkspace.shared.open(ShelfStore.filesAndFoldersSettingsURL)
            }
            Divider()
        }
        if !urls.isEmpty {
            Button("Open") { ShelfActions.open(urls) }
            Button("Quick Look") { ShelfActions.quickLook(urls) }
            Button("Show in Finder") { ShelfActions.revealInFinder(urls) }
            Divider()
            Button("Copy") { ShelfActions.copy(urls) }
            Button("AirDrop") { ShelfActions.airDrop(urls) }
            ShareLink("Share…", items: urls)
            Divider()
        }
        Button("Remove from Shelf") {
            shelf.remove(targetIDs)
            selection.subtract(targetIDs)
        }
    }
}

private struct AirDropTile: View {
    let urls: [URL]

    @Environment(\.notchAccent) private var accent
    @State private var isTargeted = false

    var body: some View {
        Button { ShelfActions.airDrop(urls) } label: {
            VStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .semibold))
                Text("AirDrop")
                    .font(.caption)
            }
            .frame(width: 84, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? accent.opacity(0.45) : .white.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(urls.isEmpty ? "Drop files here to AirDrop them" : "AirDrop \(urls.count == 1 ? "this file" : "\(urls.count) files")")
        .dropDestination(for: URL.self) { dropped, _ in
            let files = dropped.filter(\.isFileURL)
            ShelfActions.airDrop(files)
            return !files.isEmpty
        } isTargeted: {
            isTargeted = $0
        }
    }
}

private struct EmptyDropZone: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.title2)
            Text("Drop files here")
                .font(.callout)
            Text("Then drag them into any app, or AirDrop them.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(isTargeted ? 0.8 : 0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}
