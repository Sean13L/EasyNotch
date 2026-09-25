import Foundation
import Observation

/// Owns the music players and decides which one the notch shows.
@Observable
final class NowPlayingService {
    let sources: [MediaPlayerSource]

    /// Set when the user switches players by hand in the notch.
    private var choice: ActivePlayerPicker.Choice?

    @ObservationIgnored private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let runner = AppleScriptRunner()
        sources = [Spotify.profile, AppleMusic.profile].map { MediaPlayerSource(profile: $0, runner: runner) }
    }

    /// Starts listening to the players. Called once at launch (never in tests).
    func activate() {
        sources.forEach { $0.start() }
    }

    /// The player to show, or nil if none is open.
    var active: MediaPlayerSource? {
        let candidates = sources.map {
            ActivePlayerPicker.Candidate(
                player: $0.player,
                isRunning: $0.isRunning,
                isPlaying: $0.snapshot?.isPlaying == true,
                hasTrack: $0.snapshot != nil,
                lastActivity: $0.lastActivity
            )
        }
        let preferred = MediaPlayer(rawValue: settings.musicPreferredPlayer)
        let picked = ActivePlayerPicker.pick(candidates, preferred: preferred, choice: choice)
        return sources.first { $0.player == picked }
    }

    var isPlaying: Bool { active?.snapshot?.isPlaying == true }

    /// Other open players the user could switch to.
    var alternatives: [MediaPlayerSource] {
        let current = active
        return sources.filter { $0.isRunning && $0 !== current }
    }

    func switchTo(_ source: MediaPlayerSource) {
        choice = .init(player: source.player, madeAt: .now)
        Task { await source.refresh() }
    }

    /// Re-reads the shown player's state, e.g. when the music tab appears.
    func refreshActive() async {
        await active?.refresh()
    }
}
