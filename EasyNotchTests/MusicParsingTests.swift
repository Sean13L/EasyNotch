import Foundation
import Testing
@testable import EasyNotch

/// Checks that Spotify's and Music's data (their broadcasts and AppleScript replies) are read
/// correctly. The sample data mirrors what the real apps send.
struct MusicParsingTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Builds an AppleScript list reply, like the one a state script returns.
    func reply(_ items: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
        let list = NSAppleEventDescriptor.list()
        for (index, item) in items.enumerated() {
            list.insert(item, at: index + 1)
        }
        return list
    }

    func text(_ value: String) -> NSAppleEventDescriptor { NSAppleEventDescriptor(string: value) }
    func int(_ value: Int32) -> NSAppleEventDescriptor { NSAppleEventDescriptor(int32: value) }
    func real(_ value: Double) -> NSAppleEventDescriptor { NSAppleEventDescriptor(double: value) }
    func bool(_ value: Bool) -> NSAppleEventDescriptor { NSAppleEventDescriptor(boolean: value) }

    // MARK: - Spotify

    @Test func spotifyBroadcastIsRead() throws {
        let info: [AnyHashable: Any] = [
            "Player State": "Playing",
            "Name": "Blinding Lights",
            "Artist": "The Weeknd",
            "Album": "After Hours",
            "Duration": NSNumber(value: 200_040),
            "Playback Position": NSNumber(value: 12.5),
            "Track ID": "spotify:track:0VjIjW4GlUZAMYd2vXMi3b",
        ]
        let snapshot = try #require(Spotify.parseNotification(info, at: now))
        #expect(snapshot.trackID == "spotify:track:0VjIjW4GlUZAMYd2vXMi3b")
        #expect(snapshot.title == "Blinding Lights")
        #expect(snapshot.isPlaying)
        #expect(snapshot.duration == 200.04)
        #expect(snapshot.position == 12.5)
        #expect(snapshot.volume == nil)
    }

    @Test func spotifyStoppedMeansNothingLoaded() {
        #expect(Spotify.parseNotification(["Player State": "Stopped"], at: now) == nil)
        #expect(Spotify.parseState(reply([text("stopped")]), at: now) == nil)
    }

    @Test func spotifyScriptReplyIsRead() throws {
        let result = reply([
            text("paused"), text("spotify:track:abc"), text("Song"), text("Artist"), text("Album"),
            int(180_000), real(42.25), int(65), bool(true), bool(false),
            text("https://i.scdn.co/image/ab67616d0000b273"),
        ])
        let snapshot = try #require(Spotify.parseState(result, at: now))
        #expect(!snapshot.isPlaying)
        #expect(snapshot.duration == 180)
        #expect(snapshot.position == 42.25)
        #expect(snapshot.volume == 65)
        #expect(snapshot.shuffle == true)
        #expect(snapshot.repeatMode == .off)
        #expect(snapshot.artworkURL?.host == "i.scdn.co")
    }

    @Test func spotifyCommands() {
        #expect(Spotify.commandScript(.playPause) == #"tell application id "com.spotify.client" to playpause"#)
        #expect(Spotify.commandScript(.seek(to: 30.5)).hasSuffix("set player position to 30.5"))
        #expect(Spotify.commandScript(.setVolume(140)).hasSuffix("set sound volume to 100"))
    }

    // MARK: - Apple Music

    @Test func musicBroadcastIsRead() throws {
        let info: [AnyHashable: Any] = [
            "Player State": "Paused",
            "Name": "Clair de Lune",
            "Artist": "Debussy",
            "Album": "Suite bergamasque",
            "Total Time": NSNumber(value: 300_000),
            "PersistentID": NSNumber(value: -123_456_789),
        ]
        let snapshot = try #require(AppleMusic.parseNotification(info, at: now))
        #expect(!snapshot.isPlaying)
        #expect(snapshot.duration == 300)
        #expect(snapshot.position == nil)  // Music doesn't broadcast the position
    }

    @Test func musicScriptReplyMatchesTheBroadcastTrack() throws {
        let result = reply([
            text("playing"), text("Clair de Lune"), text("Debussy"), text("Suite bergamasque"),
            real(300.2), real(10), int(80), bool(false), text("one"),
        ])
        let fromScript = try #require(AppleMusic.parseState(result, at: now))
        let fromBroadcast = try #require(AppleMusic.parseNotification(
            ["Player State": "Playing", "Name": "Clair de Lune", "Artist": "Debussy", "Album": "Suite bergamasque"],
            at: now
        ))
        #expect(fromScript.trackID == fromBroadcast.trackID)
        #expect(fromScript.repeatMode == .one)
        #expect(fromScript.volume == 80)
    }

    @Test func musicRepeatCyclesThroughAllModes() {
        let script = AppleMusic.commandScript(.cycleRepeat)
        #expect(script.contains("set song repeat to all"))
        #expect(script.contains("set song repeat to one"))
        #expect(script.contains("set song repeat to off"))
    }

    // MARK: - Snapshots

    func snapshot(playing: Bool, position: Double? = 10, duration: Double? = 100) -> PlayerSnapshot {
        PlayerSnapshot(
            trackID: "t", title: "T", artist: "A", album: "B", isPlaying: playing,
            duration: duration, position: position, positionDate: now
        )
    }

    @Test func elapsedTimeRunsOnWhilePlayingAndStopsAtTheEnd() {
        #expect(snapshot(playing: true).elapsed(at: now + 5) == 15)
        #expect(snapshot(playing: true).elapsed(at: now + 500) == 100)
        #expect(snapshot(playing: false).elapsed(at: now + 5) == 10)
        #expect(snapshot(playing: true, position: nil).elapsed(at: now) == nil)
    }

    @Test func aBroadcastKeepsDetailsFromAnEarlierScriptReplyForTheSameTrack() {
        var detailed = snapshot(playing: true)
        detailed.volume = 50
        detailed.artworkURL = URL(string: "https://example.com/a.jpg")
        var broadcast = snapshot(playing: false, position: nil)
        broadcast.positionDate = now + 5

        let merged = broadcast.filling(from: detailed)
        #expect(merged.volume == 50)
        #expect(merged.artworkURL == detailed.artworkURL)
        #expect(merged.position == 15)  // estimated from the earlier snapshot
        #expect(!merged.isPlaying)
    }

    @Test func aNewTrackDoesNotInheritTheOldTracksDetails() {
        var old = snapshot(playing: true)
        old.volume = 50
        var new = snapshot(playing: true)
        new.trackID = "other"
        #expect(new.filling(from: old).volume == nil)
    }

    @Test func clockText() {
        #expect(PlayerSnapshot.clock(7) == "0:07")
        #expect(PlayerSnapshot.clock(225.9) == "3:45")
        #expect(PlayerSnapshot.clock(3723) == "1:02:03")
        #expect(PlayerSnapshot.clock(-4) == "0:00")
    }
}
