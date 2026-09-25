import Foundation

/// The music apps EasyNotch can control.
nonisolated enum MediaPlayer: String, CaseIterable, Codable, Sendable {
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .appleMusic: "Music"
        }
    }
}

/// Something the user asked a player to do.
nonisolated enum PlayerCommand: Equatable, Sendable {
    case playPause
    case next
    case previous
    case seek(to: TimeInterval)
    /// 0–100.
    case setVolume(Double)
    case toggleShuffle
    case cycleRepeat
}

/// Whether macOS lets EasyNotch send AppleScript commands to a player.
nonisolated enum AutomationPermission: Equatable, Sendable {
    /// Not checked yet.
    case unknown
    /// The player isn't open, so macOS can't say.
    case playerNotRunning
    /// macOS hasn't asked the user yet.
    case notDetermined
    case granted
    case denied
}

/// Everything specific to one music app: its IDs, its AppleScript, and how to read its data.
/// `Spotify.profile` and `AppleMusic.profile` fill this in; `MediaPlayerSource` does the rest.
nonisolated struct PlayerProfile: Sendable {
    enum ArtworkSource: Sendable {
        /// Download from `PlayerSnapshot.artworkURL`.
        case url
        /// Run this AppleScript, which returns the image data.
        case script(String)
    }

    let player: MediaPlayer
    let bundleID: String
    /// The system-wide notification the app posts when the track or play state changes.
    let notificationName: String
    /// AppleScript returning the current state, read by `parseState`.
    let stateScript: String
    let parseState: @Sendable (NSAppleEventDescriptor, Date) -> PlayerSnapshot?
    let parseNotification: @Sendable ([AnyHashable: Any], Date) -> PlayerSnapshot?
    let artwork: ArtworkSource
    let commandScript: @Sendable (PlayerCommand) -> String
}
