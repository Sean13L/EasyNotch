import Foundation

/// Tells a real file drag (e.g. a file dragged out of Finder) apart from other mouse drags,
/// like selecting text or moving a window. Pure logic, tested.
///
/// How: macOS bumps the drag pasteboard's change counter when a drag session starts. If the
/// counter differs from the one at mouse-down, it's a real drag session, and the pasteboard's
/// list of types says whether it carries files. The contents are never read.
nonisolated struct FileDragDetector: Equatable, Sendable {
    /// A drag session starts within a few pixels of movement. After this many drag events
    /// without one, it's a plain drag and we stop checking.
    static let maxChecks = 20

    private enum Phase: Equatable, Sendable {
        case idle
        case pressed(changeCount: Int, checks: Int)
        case fileDrag
        case otherDrag
    }

    private var phase: Phase = .idle

    var isDraggingFiles: Bool { phase == .fileDrag }

    mutating func mouseDown(changeCount: Int) {
        phase = .pressed(changeCount: changeCount, checks: 0)
    }

    /// Returns whether files are being dragged. The closures are only called while undecided,
    /// and `hasFiles` at most once per drag.
    mutating func mouseDragged(changeCount: () -> Int, hasFiles: () -> Bool) -> Bool {
        guard case let .pressed(start, checks) = phase else { return isDraggingFiles }
        if changeCount() != start {
            phase = hasFiles() ? .fileDrag : .otherDrag
        } else if checks + 1 >= Self.maxChecks {
            phase = .otherDrag
        } else {
            phase = .pressed(changeCount: start, checks: checks + 1)
        }
        return isDraggingFiles
    }

    mutating func mouseUp() {
        phase = .idle
    }
}
