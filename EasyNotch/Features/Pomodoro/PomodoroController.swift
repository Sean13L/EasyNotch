import AppKit
import Observation

/// Runs the Pomodoro timer: drives `PomodoroEngine` with the real clock, saves it so a running
/// timer survives quitting, and plays the sound and notification when a phase ends.
///
/// There's no once-a-second timer here. A single task sleeps until the phase's end time, and
/// the views redraw the countdown themselves while they're on screen.
@Observable
final class PomodoroController {
    private(set) var engine: PomodoroEngine {
        didSet { save() }
    }

    /// Focus sessions finished today (resets at midnight).
    var sessionsToday: Int {
        Calendar.current.isDateInToday(statsDay) ? focusSessionsOnStatsDay : 0
    }

    var config: PomodoroConfig { PomodoroConfig(settings: settings) }

    private var statsDay: Date
    private var focusSessionsOnStatsDay: Int

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifier = PomodoroNotifier()
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    /// Held while a timer runs so App Nap doesn't throttle the once-a-second countdown.
    @ObservationIgnored private var timingActivity: NSObjectProtocol?

    private enum Key {
        static let engine = "pomodoro.engine"
        static let statsDay = "pomodoro.statsDay"
        static let sessionsOnStatsDay = "pomodoro.sessionsOnStatsDay"
    }

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        engine = defaults.data(forKey: Key.engine)
            .flatMap { try? JSONDecoder().decode(PomodoroEngine.self, from: $0) } ?? PomodoroEngine()
        statsDay = defaults.object(forKey: Key.statsDay) as? Date ?? .distantPast
        focusSessionsOnStatsDay = defaults.integer(forKey: Key.sessionsOnStatsDay)
    }

    /// Called once at launch (never in tests): hooks up notifications and catches up on
    /// anything that finished while the app was quit.
    func activate() {
        notifier.activate()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForCompletion(playSound: true) }
        }
        if engine.isActive {
            Log.pomodoro.notice("Restored \(self.engine.phase.rawValue, privacy: .public): \(String(describing: self.engine.status), privacy: .public)")
        }
        // The system already showed the notification while we were quit, so stay quiet.
        checkForCompletion(playSound: false)
        // Re-arm everything for a restored timer (including its notification, in case the
        // app quit before it could be scheduled).
        phaseTimingChanged()
    }

    // MARK: - Actions

    /// The main button: Start, Pause, or Resume depending on the state.
    func startPauseOrResume() {
        switch engine.status {
        case .idle: engine.start(now: .now, config: config)
        case .running: engine.pause(now: .now)
        case .paused: engine.resume(now: .now)
        }
        Log.pomodoro.notice("Pomodoro \(self.engine.phase.rawValue, privacy: .public): \(String(describing: self.engine.status), privacy: .public)")
        phaseTimingChanged()
    }

    func skip() {
        let countBefore = engine.completedFocusSessions
        let event = engine.skip(now: .now, config: config)
        handle(event, countedFocus: engine.completedFocusSessions > countBefore, playSound: false)
    }

    func reset() {
        engine.reset()
        Log.pomodoro.notice("Pomodoro reset")
        phaseTimingChanged()
    }

    // MARK: - Private

    private func checkForCompletion(playSound: Bool) {
        let countBefore = engine.completedFocusSessions
        guard let event = engine.tick(now: .now, config: config) else { return }
        handle(event, countedFocus: engine.completedFocusSessions > countBefore, playSound: playSound)
    }

    private func handle(_ event: PomodoroEngine.Event, countedFocus: Bool, playSound: Bool) {
        Log.pomodoro.notice("Pomodoro \(event.finished.rawValue, privacy: .public) → \(event.next.rawValue, privacy: .public)\(event.wasSkipped ? " (skipped)" : "", privacy: .public)\(event.nextStartedAutomatically ? ", auto-started" : "", privacy: .public)")
        if countedFocus { countFocusSessionToday() }
        if playSound, settings.pomodoroSoundEnabled {
            NSSound(named: NSSound.Name(settings.pomodoroSound))?.play()
        }
        phaseTimingChanged()
    }

    /// Re-arms the completion check and the notification after anything that changes when
    /// the current phase will end.
    private func phaseTimingChanged() {
        scheduleCompletionCheck()
        updateTimingActivity()
        notifier.cancel()
        guard settings.pomodoroNotifications, case let .running(endsAt, _) = engine.status else { return }
        // Simulate the finish on a copy to know exactly what the notification should say.
        var preview = engine
        if let upcoming = preview.tick(now: endsAt, config: config) {
            notifier.schedule(upcoming, at: endsAt, config: config)
        }
    }

    private func scheduleCompletionCheck() {
        completionTask?.cancel()
        guard case let .running(endsAt, _) = engine.status else { return }
        completionTask = Task { [weak self] in
            // Task.sleep uses a clock that keeps counting while the Mac sleeps. Without an
            // explicit tolerance, macOS may wake us several seconds late to save power.
            try? await Task.sleep(for: .seconds(max(0, endsAt.timeIntervalSinceNow)), tolerance: .milliseconds(50))
            guard !Task.isCancelled else { return }
            self?.checkForCompletion(playSound: true)
        }
    }

    /// macOS "naps" background apps it thinks you aren't looking at, throttling their timers
    /// and redraws. Telling it a user-started timer is running keeps the countdown smooth,
    /// without keeping the Mac awake.
    private func updateTimingActivity() {
        if engine.isRunning, timingActivity == nil {
            timingActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Pomodoro timer running"
            )
        } else if !engine.isRunning, let activity = timingActivity {
            ProcessInfo.processInfo.endActivity(activity)
            timingActivity = nil
        }
    }

    private func countFocusSessionToday() {
        if !Calendar.current.isDateInToday(statsDay) {
            statsDay = .now
            focusSessionsOnStatsDay = 0
        }
        focusSessionsOnStatsDay += 1
        defaults.set(statsDay, forKey: Key.statsDay)
        defaults.set(focusSessionsOnStatsDay, forKey: Key.sessionsOnStatsDay)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engine) {
            defaults.set(data, forKey: Key.engine)
        }
    }
}

extension PomodoroConfig {
    init(settings: AppSettings) {
        self.init(
            focusDuration: settings.focusMinutes * 60,
            shortBreakDuration: settings.shortBreakMinutes * 60,
            longBreakDuration: settings.longBreakMinutes * 60,
            sessionsBeforeLongBreak: Int(settings.sessionsBeforeLongBreak.rounded()),
            autoStartBreaks: settings.autoStartBreaks,
            autoStartFocus: settings.autoStartFocus
        )
    }
}
