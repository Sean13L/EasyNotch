import Foundation

/// One file (or folder) on the shelf.
///
/// It's stored as a *bookmark*: macOS's way of pointing at a file that keeps working after the
/// file is renamed or moved, unlike a plain path.
nonisolated struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var bookmark: Data
    /// The file's name when it was last found; still shown if the file goes missing.
    var name: String
    let addedAt: Date

    /// Whether the file can be used right now.
    enum Status: Equatable, Sendable {
        case available(URL)
        /// Deleted, in the Trash, or on a drive that isn't connected.
        case missing
        /// Still there, but macOS isn't letting EasyNotch look. This happens in protected folders
        /// like Downloads when access was declined in System Settings.
        case noAccess
    }
}
