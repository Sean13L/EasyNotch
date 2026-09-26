import Foundation

/// Decides how long a paused track keeps showing beside the notch, like the iPhone keeps a
/// paused song's live activity around for a while. Pure logic, tested.
///
/// Only a track that was just playing lingers. One that was already paused when EasyNotch
/// started, or that was never played, doesn't pop up.
nonisolated struct PausedTrackLinger: Equatable, Sendable {
    /// A duration meaning "keep showing until the player quits or the track goes away".
    static let forever: TimeInterval = -1

    /// Whether a recently paused track should still be shown.
    private(set) var isShowing = false
    /// When to stop showing it. Nil when not showing, or when showing forever.
    private(set) var endsAt: Date?
    private var wasPlaying = false

    /// Call whenever playback changes. `duration` is how long to keep showing a paused
    /// track: 0 hides it right away, `forever` never hides it.
    mutating func update(isPlaying: Bool, hasTrack: Bool, duration: TimeInterval, now: Date) {
        defer { wasPlaying = isPlaying && hasTrack }
        guard hasTrack, !isPlaying else {
            // Playing (the normal live activity shows) or nothing loaded: nothing to linger.
            isShowing = false
            endsAt = nil
            return
        }
        // Already paused before this update: keep whatever was decided when it paused.
        guard wasPlaying else { return }

        if duration == 0 {
            isShowing = false
            endsAt = nil
        } else {
            isShowing = true
            endsAt = duration < 0 ? nil : now + duration
        }
    }

    /// Call when `endsAt` arrives.
    mutating func expire(now: Date) {
        guard let endsAt, now >= endsAt else { return }
        isShowing = false
        self.endsAt = nil
    }
}
