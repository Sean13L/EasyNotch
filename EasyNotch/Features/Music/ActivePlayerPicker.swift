import Foundation

/// Decides which music app the notch shows when more than one is open. Pure logic, tested.
nonisolated enum ActivePlayerPicker {
    struct Candidate: Equatable, Sendable {
        let player: MediaPlayer
        let isRunning: Bool
        let isPlaying: Bool
        let hasTrack: Bool
        let lastActivity: Date
    }

    /// The user's pick from the player switcher, and when they made it.
    struct Choice: Equatable, Sendable {
        let player: MediaPlayer
        let madeAt: Date
    }

    /// In order:
    /// 1. The player the user just switched to, until some other player starts playing.
    /// 2. A playing player (the preferred one if several are playing, else the latest to start).
    /// 3. The preferred player, if it's open.
    /// 4. The open player that was active most recently, favoring one with a track loaded.
    static func pick(_ candidates: [Candidate], preferred: MediaPlayer?, choice: Choice? = nil) -> MediaPlayer? {
        let running = candidates.filter(\.isRunning)
        guard !running.isEmpty else { return nil }

        if let choice, running.contains(where: { $0.player == choice.player }) {
            let someoneElseStartedSince = running.contains {
                $0.player != choice.player && $0.isPlaying && $0.lastActivity > choice.madeAt
            }
            if !someoneElseStartedSince { return choice.player }
        }

        let playing = running.filter(\.isPlaying)
        if let preferred, playing.contains(where: { $0.player == preferred }) {
            return preferred
        }
        if let latest = playing.max(by: { $0.lastActivity < $1.lastActivity }) {
            return latest.player
        }

        if let preferred, running.contains(where: { $0.player == preferred }) {
            return preferred
        }
        return running.max { lhs, rhs in
            (lhs.hasTrack ? 1 : 0, lhs.lastActivity) < (rhs.hasTrack ? 1 : 0, rhs.lastActivity)
        }?.player
    }
}
