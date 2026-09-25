import Foundation

nonisolated enum PomodoroPhase: String, Codable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .focus }
}

/// The user's Pomodoro preferences, as the engine needs them.
nonisolated struct PomodoroConfig: Equatable, Sendable {
    var focusDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var sessionsBeforeLongBreak: Int
    var autoStartBreaks: Bool
    var autoStartFocus: Bool

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }
}

/// The Pomodoro rules as a pure state machine: no timers, no UI, no system calls.
/// Every method takes `now`, so tests can move time around freely.
///
/// A running phase stores its *end time* rather than counting down, so sleep or a busy Mac
/// can't make it drift. It's `Codable` so a running timer survives quitting the app.
nonisolated struct PomodoroEngine: Equatable, Codable, Sendable {
    enum Status: Equatable, Codable, Sendable {
        /// Waiting for Start. `phase` is the one that will start.
        case idle
        case running(endsAt: Date, duration: TimeInterval)
        case paused(remaining: TimeInterval, duration: TimeInterval)
    }

    /// What happened when a phase finished.
    struct Event: Equatable, Sendable {
        let finished: PomodoroPhase
        let next: PomodoroPhase
        /// True when the user pressed Skip rather than the time running out.
        let wasSkipped: Bool
        let nextStartedAutomatically: Bool
    }

    private(set) var phase: PomodoroPhase = .focus
    private(set) var status: Status = .idle
    /// Focus sessions finished since the last reset.
    private(set) var completedFocusSessions = 0

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    /// Running or paused: a timer is in progress.
    var isActive: Bool { status != .idle }

    // MARK: - Actions

    mutating func start(now: Date, config: PomodoroConfig) {
        guard status == .idle else { return }
        let duration = config.duration(of: phase)
        status = .running(endsAt: now + duration, duration: duration)
    }

    mutating func pause(now: Date) {
        guard case let .running(endsAt, duration) = status else { return }
        status = .paused(remaining: max(0, endsAt.timeIntervalSince(now)), duration: duration)
    }

    mutating func resume(now: Date) {
        guard case let .paused(remaining, duration) = status else { return }
        status = .running(endsAt: now + remaining, duration: duration)
    }

    /// Finishes the current phase immediately and moves on. A focus session counts only if it
    /// had been started.
    mutating func skip(now: Date, config: PomodoroConfig) -> Event {
        advance(now: now, config: config, skipped: true, countsFocus: status != .idle)
    }

    mutating func reset() {
        phase = .focus
        status = .idle
        completedFocusSessions = 0
    }

    /// Completes the running phase if its time is up. After a long sleep this completes just
    /// one phase and starts the next from `now`, so you still get your full break.
    mutating func tick(now: Date, config: PomodoroConfig) -> Event? {
        guard case let .running(endsAt, _) = status, now >= endsAt else { return nil }
        return advance(now: now, config: config, skipped: false, countsFocus: true)
    }

    // MARK: - Reading

    func remaining(at now: Date, config: PomodoroConfig) -> TimeInterval {
        switch status {
        case .idle: config.duration(of: phase)
        case let .running(endsAt, _): max(0, endsAt.timeIntervalSince(now))
        case let .paused(remaining, _): remaining
        }
    }

    /// How much of the current phase has elapsed, from 0 to 1.
    func progress(at now: Date, config: PomodoroConfig) -> Double {
        let total: TimeInterval
        switch status {
        case .idle: return 0
        case let .running(_, duration), let .paused(_, duration): total = duration
        }
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: now, config: config) / total))
    }

    /// Filled dots in the ●●○○ indicator. Shows a full row during the long break.
    func sessionsCompletedInCycle(config: PomodoroConfig) -> Int {
        let perCycle = max(1, config.sessionsBeforeLongBreak)
        if phase == .longBreak { return perCycle }
        return completedFocusSessions % perCycle
    }

    // MARK: - Private

    private mutating func advance(
        now: Date, config: PomodoroConfig, skipped: Bool, countsFocus: Bool
    ) -> Event {
        let finished = phase
        let next: PomodoroPhase
        if finished == .focus {
            if countsFocus { completedFocusSessions += 1 }
            let perCycle = max(1, config.sessionsBeforeLongBreak)
            let isLongBreakDue = completedFocusSessions > 0 && completedFocusSessions % perCycle == 0
            next = countsFocus && isLongBreakDue ? .longBreak : .shortBreak
        } else {
            next = .focus
        }

        let autoStart = next.isBreak ? config.autoStartBreaks : config.autoStartFocus
        phase = next
        if autoStart {
            let duration = config.duration(of: next)
            status = .running(endsAt: now + duration, duration: duration)
        } else {
            status = .idle
        }
        return Event(finished: finished, next: next, wasSkipped: skipped, nextStartedAutomatically: autoStart)
    }
}
