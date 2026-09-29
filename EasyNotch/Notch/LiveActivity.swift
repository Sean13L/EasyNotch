/// Something a feature wants to show beside the closed notch (the "compact" state).
enum LiveActivity: Equatable {
    case pomodoro
    case music
    case meeting
    /// The charging flash or a low-battery warning.
    case battery
    /// A big download or upload in progress.
    case network
    /// Empty wings, shown only while previewing the live activity width in Settings.
    case placeholder

    /// The tab to show when the notch opens from this activity.
    var module: NotchModule? {
        switch self {
        case .pomodoro: .pomodoro
        case .music: .music
        case .meeting: .calendar
        case .battery: .battery
        case .network: .system
        case .placeholder: nil
        }
    }

    /// Everything that could want the wings right now. Each flag should already account for the
    /// user's settings (e.g. "show beside the notch" and hidden tabs).
    struct Candidates: Equatable {
        var chargingFlash = false
        var meetingSoon = false
        var timerRunning = false
        var musicPlaying = false
        var musicRecentlyPaused = false
        var lowBattery = false
        var bigTransfer = false
        var timerPaused = false
    }

    /// Picks what to show when several things are going on.
    ///
    /// Alerts come first: the brief charging flash, then a meeting about to start, then low
    /// battery. The meeting and battery alerts stay until the user opens the notch.
    ///
    /// Next, the tab the user last had open (`preferring`) wins if it has something to show, so
    /// switching to the Pomodoro tab and closing the notch puts the timer beside it, even while
    /// music plays.
    ///
    /// Otherwise, most important first:
    /// 1. the charging flash
    /// 2. a meeting about to start
    /// 3. a running timer
    /// 4. playing music, then music that was just paused
    /// 5. low battery
    /// 6. a big transfer
    /// 7. a paused timer
    static func resolve(_ candidates: Candidates, preferring preferred: NotchModule? = nil) -> LiveActivity? {
        let ranked: [(Bool, LiveActivity)] = [
            (candidates.chargingFlash, .battery),
            (candidates.meetingSoon, .meeting),
            (candidates.timerRunning, .pomodoro),
            (candidates.musicPlaying || candidates.musicRecentlyPaused, .music),
            (candidates.lowBattery, .battery),
            (candidates.bigTransfer, .network),
            (candidates.timerPaused, .pomodoro),
        ]
        if candidates.chargingFlash { return .battery }
        if candidates.meetingSoon { return .meeting }
        if candidates.lowBattery { return .battery }
        if let preferred, let match = ranked.first(where: { $0.0 && $0.1.module == preferred }) {
            return match.1
        }
        return ranked.first { $0.0 }?.1
    }
}

/// What the notch is showing right now.
enum NotchPresentation: Equatable {
    case closed
    case compact(LiveActivity)
    case open
}
