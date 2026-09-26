import Foundation
import Testing
@testable import EasyNotch

struct PausedTrackLingerTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A linger that has seen a track playing.
    func playing() -> PausedTrackLinger {
        var linger = PausedTrackLinger()
        linger.update(isPlaying: true, hasTrack: true, duration: 60, now: t0)
        return linger
    }

    @Test func pausingKeepsTheTrackShowingForTheChosenTime() {
        var linger = playing()
        linger.update(isPlaying: false, hasTrack: true, duration: 60, now: t0 + 10)
        #expect(linger.isShowing)
        #expect(linger.endsAt == t0 + 70)

        linger.expire(now: t0 + 69)
        #expect(linger.isShowing)
        linger.expire(now: t0 + 70)
        #expect(!linger.isShowing)
    }

    @Test func aTrackThatWasNeverPlayingDoesNotPopUp() {
        var linger = PausedTrackLinger()
        linger.update(isPlaying: false, hasTrack: true, duration: 60, now: t0)
        #expect(!linger.isShowing)
    }

    @Test func laterUpdatesWhilePausedDoNotRestartTheClock() {
        var linger = playing()
        linger.update(isPlaying: false, hasTrack: true, duration: 60, now: t0 + 10)
        linger.update(isPlaying: false, hasTrack: true, duration: 60, now: t0 + 50)
        #expect(linger.endsAt == t0 + 70)
    }

    @Test func playingAgainOrLosingTheTrackEndsIt() {
        var resumed = playing()
        resumed.update(isPlaying: false, hasTrack: true, duration: 60, now: t0)
        resumed.update(isPlaying: true, hasTrack: true, duration: 60, now: t0 + 5)
        #expect(!resumed.isShowing)

        var quit = playing()
        quit.update(isPlaying: false, hasTrack: true, duration: 60, now: t0)
        quit.update(isPlaying: false, hasTrack: false, duration: 60, now: t0 + 5)
        #expect(!quit.isShowing)
    }

    @Test func zeroHidesRightAwayAndForeverNeverExpires() {
        var immediate = playing()
        immediate.update(isPlaying: false, hasTrack: true, duration: 0, now: t0)
        #expect(!immediate.isShowing)

        var forever = playing()
        forever.update(isPlaying: false, hasTrack: true, duration: PausedTrackLinger.forever, now: t0)
        #expect(forever.isShowing)
        #expect(forever.endsAt == nil)
        forever.expire(now: t0 + 1_000_000)
        #expect(forever.isShowing)
    }
}
