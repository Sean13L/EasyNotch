import Foundation
import Testing
@testable import EasyNotch

struct ActivePlayerPickerTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func candidate(
        _ player: MediaPlayer, running: Bool = true, playing: Bool = false,
        track: Bool = true, active: TimeInterval = 0
    ) -> ActivePlayerPicker.Candidate {
        .init(player: player, isRunning: running, isPlaying: playing, hasTrack: track, lastActivity: t0 + active)
    }

    @Test func nothingOpenMeansNothingToShow() {
        let picked = ActivePlayerPicker.pick([candidate(.spotify, running: false)], preferred: nil)
        #expect(picked == nil)
    }

    @Test func thePlayingPlayerWins() {
        let picked = ActivePlayerPicker.pick(
            [candidate(.spotify, active: 50), candidate(.appleMusic, playing: true, active: 10)],
            preferred: nil
        )
        #expect(picked == .appleMusic)
    }

    @Test func ifBothPlayTheLatestToStartWins() {
        let picked = ActivePlayerPicker.pick(
            [candidate(.spotify, playing: true, active: 10), candidate(.appleMusic, playing: true, active: 20)],
            preferred: nil
        )
        #expect(picked == .appleMusic)
    }

    @Test func thePreferredPlayerWinsTiesButNotAgainstMusicThatIsPlaying() {
        let bothPlaying = [candidate(.spotify, playing: true, active: 10), candidate(.appleMusic, playing: true, active: 20)]
        #expect(ActivePlayerPicker.pick(bothPlaying, preferred: .spotify) == .spotify)

        let onlyMusicPlaying = [candidate(.spotify), candidate(.appleMusic, playing: true)]
        #expect(ActivePlayerPicker.pick(onlyMusicPlaying, preferred: .spotify) == .appleMusic)

        let nothingPlaying = [candidate(.spotify, active: 10), candidate(.appleMusic, active: 20)]
        #expect(ActivePlayerPicker.pick(nothingPlaying, preferred: .spotify) == .spotify)
    }

    @Test func withNothingPlayingAPausedTrackBeatsAnEmptyPlayer() {
        let picked = ActivePlayerPicker.pick(
            [candidate(.spotify, track: true, active: 10), candidate(.appleMusic, track: false, active: 20)],
            preferred: nil
        )
        #expect(picked == .spotify)
    }

    @Test func aManualSwitchHoldsUntilAnotherPlayerStartsPlaying() {
        let choice = ActivePlayerPicker.Choice(player: .spotify, madeAt: t0 + 30)

        let musicStillPlayingFromBefore = [candidate(.spotify), candidate(.appleMusic, playing: true, active: 20)]
        #expect(ActivePlayerPicker.pick(musicStillPlayingFromBefore, preferred: nil, choice: choice) == .spotify)

        let musicStartedAfterwards = [candidate(.spotify), candidate(.appleMusic, playing: true, active: 40)]
        #expect(ActivePlayerPicker.pick(musicStartedAfterwards, preferred: nil, choice: choice) == .appleMusic)
    }

    // MARK: - What shows beside the notch

    @Test func liveActivityPriority() {
        func resolve(running: Bool = false, paused: Bool = false, playing: Bool = false, recentlyPaused: Bool = false) -> LiveActivity? {
            LiveActivity.resolve(timerRunning: running, timerPaused: paused, musicPlaying: playing, musicRecentlyPaused: recentlyPaused)
        }
        #expect(resolve(running: true, playing: true) == .pomodoro)
        #expect(resolve(paused: true, playing: true) == .music)
        #expect(resolve(paused: true, recentlyPaused: true) == .music)
        #expect(resolve(paused: true) == .pomodoro)
        #expect(resolve() == nil)
    }
}
