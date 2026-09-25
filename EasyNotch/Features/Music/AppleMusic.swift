import Foundation

/// Everything specific to Apple's Music app.
nonisolated enum AppleMusic {
    static let bundleID = "com.apple.Music"

    static let profile = PlayerProfile(
        player: .appleMusic,
        bundleID: bundleID,
        notificationName: "com.apple.Music.playerInfo",
        stateScript: stateScript,
        parseState: parseState,
        parseNotification: parseNotification,
        artwork: .script(artworkScript),
        commandScript: commandScript
    )

    /// Returns {state} when stopped, otherwise
    /// {state, name, artist, album, duration (s), position (s), volume, shuffle enabled, song repeat}.
    static let stateScript = """
        tell application id "\(bundleID)"
            with timeout of 3 seconds
                set playerState to player state as string
                if playerState is "stopped" then return {playerState}
                set t to current track
                return {playerState, name of t, artist of t, album of t, duration of t, ¬
                    player position, sound volume, shuffle enabled, song repeat as string}
            end timeout
        end tell
        """

    /// Returns the current track's cover image data, or `missing value`.
    static let artworkScript = """
        tell application id "\(bundleID)"
            with timeout of 3 seconds
                if (count of artworks of current track) is 0 then return missing value
                return raw data of artwork 1 of current track
            end timeout
        end tell
        """

    static func parseState(_ result: NSAppleEventDescriptor, at now: Date) -> PlayerSnapshot? {
        guard result.numberOfItems >= 9,
              let state = result.atIndex(1)?.stringValue, state != "stopped"
        else { return nil }
        let title = result.atIndex(2)?.stringValue ?? ""
        let artist = result.atIndex(3)?.stringValue ?? ""
        let album = result.atIndex(4)?.stringValue ?? ""
        return PlayerSnapshot(
            trackID: trackID(title: title, artist: artist, album: album),
            title: title,
            artist: artist,
            album: album,
            isPlaying: state == "playing",
            duration: result.atIndex(5)?.doubleValue,
            position: result.atIndex(6)?.doubleValue,
            positionDate: now,
            volume: result.atIndex(7)?.doubleValue,
            shuffle: result.atIndex(8)?.booleanValue,
            repeatMode: result.atIndex(9)?.stringValue.flatMap(PlayerSnapshot.RepeatMode.init(rawValue:))
        )
    }

    /// Music's broadcast includes the track, state and duration (ms), but not the position.
    static func parseNotification(_ info: [AnyHashable: Any], at now: Date) -> PlayerSnapshot? {
        guard let state = info["Player State"] as? String, state != "Stopped" else { return nil }
        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        return PlayerSnapshot(
            trackID: trackID(title: title, artist: artist, album: album),
            title: title,
            artist: artist,
            album: album,
            isPlaying: state == "Playing",
            duration: playerNumber(info["Total Time"]).map { $0 / 1000 },
            position: nil,
            positionDate: now
        )
    }

    static func commandScript(_ command: PlayerCommand) -> String {
        let tell = "tell application id \"\(bundleID)\""
        switch command {
        case .playPause: return "\(tell) to playpause"
        case .next: return "\(tell) to next track"
        case .previous: return "\(tell) to previous track"
        case let .seek(seconds): return "\(tell) to set player position to \(max(0, seconds))"
        case let .setVolume(volume): return "\(tell) to set sound volume to \(Int(min(max(volume, 0), 100).rounded()))"
        case .toggleShuffle: return "\(tell) to set shuffle enabled to not shuffle enabled"
        case .cycleRepeat:
            // off → all → one → off, like the button in the Music app.
            return """
                \(tell)
                    set r to song repeat
                    if r is off then
                        set song repeat to all
                    else if r is all then
                        set song repeat to one
                    else
                        set song repeat to off
                    end if
                end tell
                """
        }
    }

    /// The notification and AppleScript use different track IDs, so identify tracks by
    /// their details instead; both sources agree on those.
    private static func trackID(title: String, artist: String, album: String) -> String {
        "\(title)|\(artist)|\(album)"
    }
}
