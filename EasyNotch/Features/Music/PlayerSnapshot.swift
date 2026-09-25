import Foundation

/// What a music player is doing at one moment. Built from the player's broadcast
/// notification (no permission needed) or from AppleScript (more detail, needs permission).
nonisolated struct PlayerSnapshot: Equatable, Sendable {
    enum RepeatMode: String, Sendable {
        case off
        case one
        case all
    }

    /// Identifies the track, to notice when it changes.
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var duration: TimeInterval?
    /// Playback position when the snapshot was taken (`positionDate`).
    var position: TimeInterval?
    var positionDate: Date
    /// 0–100.
    var volume: Double?
    var shuffle: Bool?
    var repeatMode: RepeatMode?
    var artworkURL: URL?

    /// The current position, moved forward by the time since the snapshot while playing.
    /// This lets the progress bar run without asking the player every second.
    func elapsed(at now: Date) -> TimeInterval? {
        guard let position else { return nil }
        let value = isPlaying ? position + now.timeIntervalSince(positionDate) : position
        let clamped = max(0, value)
        return duration.map { min(clamped, $0) } ?? clamped
    }

    /// Fills in details this snapshot lacks from an older snapshot of the same track.
    /// Notifications don't include volume, artwork, and so on, so a notification-based snapshot
    /// keeps what an earlier AppleScript snapshot knew.
    func filling(from previous: PlayerSnapshot?) -> PlayerSnapshot {
        guard let previous, previous.trackID == trackID else { return self }
        var merged = self
        merged.duration = duration ?? previous.duration
        if position == nil {
            merged.position = previous.elapsed(at: positionDate)
        }
        merged.volume = volume ?? previous.volume
        merged.shuffle = shuffle ?? previous.shuffle
        merged.repeatMode = repeatMode ?? previous.repeatMode
        merged.artworkURL = artworkURL ?? previous.artworkURL
        return merged
    }

    /// "0:07", "3:45", "1:02:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

/// Reads a number from notification or AppleScript data, whatever numeric type it arrived as.
nonisolated func playerNumber(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue
}
