import SwiftUI

/// One file on the shelf: its thumbnail and name. A file that's missing, or that EasyNotch
/// isn't allowed to read, is dimmed and labeled.
struct ShelfItemView: View {
    let item: ShelfItem
    let status: ShelfItem.Status
    let isSelected: Bool
    let thumbnails: ShelfThumbnails

    @Environment(\.notchAccent) private var accent
    @State private var thumbnail: NSImage?

    private static let size: CGFloat = 56

    private var url: URL? {
        if case let .available(url) = status { return url }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let thumbnail, url != nil {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: placeholderSymbol)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Self.size, height: Self.size)

            Text(label)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 72)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? accent.opacity(0.4) : .clear)
        )
        .opacity(url == nil ? 0.45 : 1)
        .contentShape(Rectangle())
        .help(helpText)
        .task(id: url) {
            thumbnail = if let url { await thumbnails.image(for: url, size: Self.size) } else { nil }
        }
    }

    private var label: String {
        switch status {
        case .available: item.name
        case .missing: "Missing"
        case .noAccess: "No access"
        }
    }

    private var placeholderSymbol: String {
        switch status {
        case .available: "doc"
        case .missing: "questionmark.folder"
        case .noAccess: "lock.fill"
        }
    }

    private var helpText: String {
        switch status {
        case let .available(url): url.path
        case .missing: "\(item.name) can't be found. It may have been deleted or be on a disconnected drive."
        case .noAccess: "EasyNotch isn't allowed to open \(item.name)'s folder. Right-click to allow access in System Settings."
        }
    }
}
