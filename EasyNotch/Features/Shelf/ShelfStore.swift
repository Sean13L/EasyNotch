import Foundation
import Observation

/// The files on the shelf, newest first. Saved to
/// `~/Library/Application Support/EasyNotch/shelf.json` so they survive quitting the app.
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    /// Where each item's file is right now. Files that are missing or can't be accessed have
    /// no entry.
    private(set) var locations: [ShelfItem.ID: URL] = [:]
    /// Items whose file is still there but that macOS won't let EasyNotch read.
    private(set) var blocked: Set<ShelfItem.ID> = []
    /// True while files are being dragged over the open notch, to highlight the drop zone.
    var isDropTargeted = false

    @ObservationIgnored let thumbnails = ShelfThumbnails()
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let now: () -> Date

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("EasyNotch", isDirectory: true)
    }

    /// `directory` and `now` are replaceable so tests can use temporary files and fake dates.
    init(settings: AppSettings, directory: URL = ShelfStore.defaultDirectory, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.fileURL = directory.appendingPathComponent("shelf.json")
        self.now = now
        load()
    }

    // MARK: - Reading

    func url(for item: ShelfItem) -> URL? {
        locations[item.id]
    }

    func isMissing(_ item: ShelfItem) -> Bool {
        locations[item.id] == nil
    }

    func status(of item: ShelfItem) -> ShelfItem.Status {
        if let url = locations[item.id] { return .available(url) }
        return blocked.contains(item.id) ? .noAccess : .missing
    }

    /// The files that still exist, in shelf order.
    var availableURLs: [URL] {
        items.compactMap { locations[$0.id] }
    }

    func urls(for ids: Set<ShelfItem.ID>) -> [URL] {
        items.filter { ids.contains($0.id) }.compactMap { locations[$0.id] }
    }

    var confirmsBeforeClearing: Bool { settings.shelfConfirmClear }

    /// Opens System Settings → Privacy & Security → Files & Folders, where access to protected
    /// folders like Downloads can be turned back on.
    static let filesAndFoldersSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!

    // MARK: - Changing

    /// Adds files to the front, keeping their order. A file that's already on the shelf moves
    /// to the front instead of appearing twice. The oldest items drop off past the maximum.
    func add(_ urls: [URL]) {
        var added: [ShelfItem] = []
        for url in urls where url.isFileURL {
            let canonical = Self.canonical(url)
            let path = canonical.path
            guard !added.contains(where: { locations[$0.id]?.path == path }) else { continue }
            if let existing = items.first(where: { locations[$0.id]?.path == path }) {
                items.removeAll { $0.id == existing.id }
                added.append(existing)
                continue
            }
            guard let bookmark = try? url.bookmarkData() else {
                Log.shelf.error("Couldn't bookmark \(url.lastPathComponent, privacy: .public)")
                continue
            }
            let item = ShelfItem(id: UUID(), bookmark: bookmark, name: url.lastPathComponent, addedAt: now())
            locations[item.id] = canonical
            added.append(item)
        }
        guard !added.isEmpty else { return }
        items.insert(contentsOf: added, at: 0)
        trimToMaximum()
        Log.shelf.notice("Added \(added.count) item(s); shelf has \(self.items.count)")
        save()
    }

    func remove(_ ids: Set<ShelfItem.ID>) {
        items.removeAll { ids.contains($0.id) }
        ids.forEach {
            locations[$0] = nil
            blocked.remove($0)
        }
        save()
    }

    /// Called when files dragged out of the shelf were dropped somewhere. Removes them if the
    /// user turned on "Remove files after dragging them out".
    func finishedDraggingOut(_ urls: [URL]) {
        guard settings.shelfRemoveAfterDragOut else { return }
        let paths = Set(urls.map { Self.canonical($0).path })
        let ids = Set(items.filter { locations[$0.id].map { paths.contains($0.path) } == true }.map(\.id))
        guard !ids.isEmpty else { return }
        Log.shelf.notice("Removed \(ids.count) item(s) after dragging them out")
        remove(ids)
    }

    func removeAll() {
        items.removeAll()
        locations.removeAll()
        blocked.removeAll()
        Log.shelf.notice("Shelf cleared")
        save()
    }

    /// Finds every file again, e.g. when the shelf appears. It follows renames and moves,
    /// refreshes outdated bookmarks, marks missing files, and removes items older than the
    /// auto-remove setting.
    func refresh() {
        var changed = removeExpired()
        for index in items.indices {
            let item = items[index]
            var isStale = false
            let resolved = try? URL(
                resolvingBookmarkData: item.bookmark,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard let url = resolved, Self.isAvailable(url) else {
                locations[item.id] = nil
                // Tell "deleted" apart from "not allowed to look" using where the file last was.
                let lastPath = resolved?.path
                    ?? URL.resourceValues(forKeys: [.pathKey], fromBookmarkData: item.bookmark)?.path
                if let lastPath, Self.isAccessDenied(atPath: lastPath) {
                    blocked.insert(item.id)
                } else {
                    blocked.remove(item.id)
                }
                continue
            }
            blocked.remove(item.id)
            locations[item.id] = Self.canonical(url)
            if url.lastPathComponent != item.name {
                items[index].name = url.lastPathComponent
                changed = true
            }
            if isStale, let fresh = try? url.bookmarkData() {
                items[index].bookmark = fresh
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Private

    /// One spelling per file, so the same file is never mistaken for two (on macOS `/var/…`
    /// and `/private/var/…` are the same folder, for example).
    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// A file counts as available if it exists and isn't sitting in the Trash (a bookmark
    /// happily follows a file into the Trash).
    private static func isAvailable(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) && !url.pathComponents.contains(".Trash")
    }

    /// True when the file is there but reading its details is refused, which is what macOS does
    /// in a protected folder the user hasn't allowed.
    private static func isAccessDenied(atPath path: String) -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: path)
            return false
        } catch let error as NSError {
            let posix = (error.userInfo[NSUnderlyingErrorKey] as? NSError)?.code
            return error.code == NSFileReadNoPermissionError || posix == Int(EPERM) || posix == Int(EACCES)
        }
    }

    private func trimToMaximum() {
        let maximum = max(1, Int(settings.shelfMaxItems.rounded()))
        guard items.count > maximum else { return }
        items.suffix(from: maximum).forEach { locations[$0.id] = nil }
        items.removeLast(items.count - maximum)
    }

    /// Returns true if anything was removed.
    private func removeExpired() -> Bool {
        let days = settings.shelfAutoRemoveDays
        guard days > 0 else { return false }
        let cutoff = now().addingTimeInterval(-days * 86_400)
        let expired = items.filter { $0.addedAt < cutoff }
        guard !expired.isEmpty else { return false }
        items.removeAll { $0.addedAt < cutoff }
        expired.forEach { locations[$0.id] = nil }
        Log.shelf.notice("Auto-removed \(expired.count) old item(s)")
        return true
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            items = try JSONDecoder().decode([ShelfItem].self, from: data)
            refresh()
        } catch {
            Log.shelf.error("Couldn't read the shelf: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            Log.shelf.error("Couldn't save the shelf: \(error.localizedDescription, privacy: .public)")
        }
    }
}
