import Foundation
import Testing
@testable import EasyNotch

struct PomodoroEngineTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let minute: TimeInterval = 60

    func config(autoStartBreaks: Bool = true, autoStartFocus: Bool = false) -> PomodoroConfig {
        PomodoroConfig(
            focusDuration: 25 * minute,
            shortBreakDuration: 5 * minute,
            longBreakDuration: 15 * minute,
            sessionsBeforeLongBreak: 4,
            autoStartBreaks: autoStartBreaks,
            autoStartFocus: autoStartFocus
        )
    }

    /// Runs the current phase to completion and returns what happened.
    func finishPhase(_ engine: inout PomodoroEngine, at now: inout Date, config: PomodoroConfig) -> PomodoroEngine.Event? {
        if engine.status == .idle { engine.start(now: now, config: config) }
        now += engine.remaining(at: now, config: config)
        return engine.tick(now: now, config: config)
    }

    // MARK: - Basics

    @Test func startsIdleOnFocusWithFullTime() {
        let engine = PomodoroEngine()
        #expect(engine.phase == .focus)
        #expect(engine.status == .idle)
        #expect(engine.remaining(at: t0, config: config()) == 25 * minute)
        #expect(engine.progress(at: t0, config: config()) == 0)
    }

    @Test func startCountsDownFromTheEndTime() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        #expect(engine.status == .running(endsAt: t0 + 25 * minute, duration: 25 * minute))
        #expect(engine.remaining(at: t0 + minute, config: config()) == 24 * minute)
        #expect(abs(engine.progress(at: t0 + 5 * minute, config: config()) - 0.2) < 1e-9)
    }

    @Test func pausedTimeDoesNotCount() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        engine.pause(now: t0 + 10 * minute)
        #expect(engine.remaining(at: t0 + 60 * minute, config: config()) == 15 * minute)

        engine.resume(now: t0 + 60 * minute)
        #expect(engine.status == .running(endsAt: t0 + 75 * minute, duration: 25 * minute))
    }

    @Test func tickBeforeTheEndDoesNothing() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        #expect(engine.tick(now: t0 + 24 * minute, config: config()) == nil)
        #expect(engine.phase == .focus)
    }

    // MARK: - Completing phases

    @Test func finishedFocusAutoStartsAShortBreak() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        let event = engine.tick(now: t0 + 25 * minute, config: config())

        #expect(event == .init(finished: .focus, next: .shortBreak, wasSkipped: false, nextStartedAutomatically: true))
        #expect(engine.completedFocusSessions == 1)
        #expect(engine.status == .running(endsAt: t0 + 30 * minute, duration: 5 * minute))
    }

    @Test func withoutAutoStartTheNextPhaseWaits() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config(autoStartBreaks: false))
        let event = engine.tick(now: t0 + 25 * minute, config: config(autoStartBreaks: false))

        #expect(event?.nextStartedAutomatically == false)
        #expect(engine.phase == .shortBreak)
        #expect(engine.status == .idle)
    }

    @Test func breakEndsBackOnIdleFocusByDefault() {
        var engine = PomodoroEngine()
        var now = t0
        _ = finishPhase(&engine, at: &now, config: config())  // focus
        let event = finishPhase(&engine, at: &now, config: config())  // short break

        #expect(event?.next == .focus)
        #expect(engine.status == .idle)
    }

    @Test func everyFourthFocusEarnsALongBreakThenTheCycleResets() {
        var engine = PomodoroEngine()
        var now = t0
        let c = config(autoStartFocus: true)

        for session in 1...3 {
            #expect(finishPhase(&engine, at: &now, config: c)?.next == .shortBreak)
            #expect(engine.sessionsCompletedInCycle(config: c) == session)
            _ = finishPhase(&engine, at: &now, config: c)
        }
        #expect(finishPhase(&engine, at: &now, config: c)?.next == .longBreak)
        #expect(engine.sessionsCompletedInCycle(config: c) == 4)
        #expect(engine.remaining(at: now, config: c) == 15 * minute)

        #expect(finishPhase(&engine, at: &now, config: c)?.next == .focus)
        #expect(engine.sessionsCompletedInCycle(config: c) == 0)
        #expect(engine.completedFocusSessions == 4)
    }

    @Test func afterALongSleepOnlyOnePhaseCompletesAndTheNextStartsNow() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config(autoStartFocus: true))
        let wake = t0 + 3 * 60 * minute  // three hours later

        let event = engine.tick(now: wake, config: config(autoStartFocus: true))
        #expect(event?.finished == .focus)
        #expect(engine.status == .running(endsAt: wake + 5 * minute, duration: 5 * minute))
        #expect(engine.tick(now: wake, config: config(autoStartFocus: true)) == nil)
    }

    // MARK: - Skip and reset

    @Test func skippingARunningFocusCountsButIsFlagged() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        let event = engine.skip(now: t0 + minute, config: config())

        #expect(event.wasSkipped)
        #expect(event.next == .shortBreak)
        #expect(engine.completedFocusSessions == 1)
    }

    @Test func skippingAnUnstartedFocusDoesNotCount() {
        var engine = PomodoroEngine()
        _ = engine.skip(now: t0, config: config())
        #expect(engine.completedFocusSessions == 0)
        #expect(engine.phase == .shortBreak)
    }

    @Test func resetGoesBackToTheBeginning() {
        var engine = PomodoroEngine()
        var now = t0
        _ = finishPhase(&engine, at: &now, config: config())
        engine.reset()

        #expect(engine == PomodoroEngine())
    }

    // MARK: - Settings changes and persistence

    @Test func changingLengthsMidPhaseKeepsTheCurrentEndTime() {
        var engine = PomodoroEngine()
        engine.start(now: t0, config: config())
        var shorter = config()
        shorter.focusDuration = 10 * minute

        #expect(engine.remaining(at: t0, config: shorter) == 25 * minute)
        #expect(abs(engine.progress(at: t0 + 5 * minute, config: shorter) - 0.2) < 1e-9)
    }

    @Test func aRunningTimerSurvivesSavingAndLoading() throws {
        var engine = PomodoroEngine()
        var now = t0
        _ = finishPhase(&engine, at: &now, config: config())
        engine.pause(now: now + minute)

        let data = try JSONEncoder().encode(engine)
        let restored = try JSONDecoder().decode(PomodoroEngine.self, from: data)
        #expect(restored == engine)
    }

    // MARK: - Clock text

    @Test func clockTextRoundsUpToWholeSeconds() {
        #expect(PomodoroClock.string(for: 25 * minute) == "25:00")
        #expect(PomodoroClock.string(for: 1499.4) == "25:00")
        #expect(PomodoroClock.string(for: 59) == "00:59")
        #expect(PomodoroClock.string(for: 0.2) == "00:01")
        #expect(PomodoroClock.string(for: 0) == "00:00")
        #expect(PomodoroClock.string(for: 60.000_000_1) == "01:00")
        #expect(PomodoroClock.string(for: 90 * minute) == "90:00")
    }
}
