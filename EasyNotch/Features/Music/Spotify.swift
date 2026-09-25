import Foundation

/// Everything specific to Spotify.
nonisolated enum Spotify {
    static let bundleID = "com.spotify.client"

    static let profile = PlayerProfile(
        player: .spotify,
        bundleID: bundleID,
        notificationName: "com.spotify.client.PlaybackStateChanged",
        stateScript: stateScript,
        parseState: parseState,
        parseNotification: parseNotification,
        artwork: .url,
        commandScript: commandScript
    )

    /// Returns {state} when stopped, otherwise
    /// {state, id, name, artist, album, duration (ms), position (s), volume, shuffling, repeating, artwork url}.
    static let stateScript = """
        tell application id "\(bundleID)"
            with timeout of 3 seconds
                set playerState to player state as string
                if playerState is "stopped" then return {playerState}
                set t to current track
                return {playerState, id of t, name of t, artist of t, album of t, duration of t, ¬
                    player position, sound volume, shuffling, repeating, artwork url of t}
            end timeout
        end tell
        """

    static func parseState(_ result: NSAppleEventDescriptor, at now: Date) -> PlayerSnapshot? {
        guard result.numberOfItems >= 11,
              let state = result.atIndex(1)?.stringValue, state != "stopped",
              let id = result.atIndex(2)?.stringValue
        else { return nil }
        return PlayerSnapshot(
            trackID: id,
            title: result.atIndex(3)?.stringValue ?? "",
            artist: result.atIndex(4)?.stringValue ?? "",
            album: result.atIndex(5)?.stringValue ?? "",
            isPlaying: state == "playing",
            duration: result.atIndex(6).map { $0.doubleValue / 1000 },
            position: result.atIndex(7)?.doubleValue,
            positionDate: now,
            volume: result.atIndex(8)?.doubleValue,
            shuffle: result.atIndex(9)?.booleanValue,
            repeatMode: result.atIndex(10).map { $0.booleanValue ? .all : .off },
            artworkURL: result.atIndex(11)?.stringValue.flatMap(URL.init(string:))
        )
    }

    /// Spotify's broadcast includes the track, state, duration (ms) and position (s).
    static func parseNotification(_ info: [AnyHashable: Any], at now: Date) -> PlayerSnapshot? {
        guard let state = info["Player State"] as? String, state != "Stopped" else { return nil }
        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        return PlayerSnapshot(
            trackID: info["Track ID"] as? String ?? "\(title)|\(artist)",
            title: title,
            artist: artist,
            album: info["Album"] as? String ?? "",
            isPlaying: state == "Playing",
            duration: playerNumber(info["Duration"]).map { $0 / 1000 },
            position: playerNumber(info["Playback Position"]),
            positionDate: now
        )
    }

    static func commandScript(_ command: PlayerCommand) -> String {
        let body = switch command {
        case .playPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        case let .seek(seconds): "set player position to \(max(0, seconds))"
        case let .setVolume(volume): "set sound volume to \(Int(min(max(volume, 0), 100).rounded()))"
        case .toggleShuffle: "set shuffling to not shuffling"
        case .cycleRepeat: "set repeating to not repeating"
        }
        return "tell application id \"\(bundleID)\" to \(body)"
    }
}
