/// Something a feature wants to show beside the closed notch (the "compact" state).
enum LiveActivity: Equatable {
    case pomodoro
    case music
    /// Empty wings, shown only while previewing the live activity width in Settings.
    case placeholder

    /// The tab to show when the notch opens from this activity.
    var module: NotchModule? {
        switch self {
        case .pomodoro: .pomodoro
        case .music: .music
        case .placeholder: nil
        }
    }

    /// Picks what to show when several things are going on, in order:
    /// 1. a running timer (it's time-sensitive)
    /// 2. playing music
    /// 3. music that was just paused
    /// 4. a paused timer
    ///
    /// Each flag should already account for the user's "show beside the notch" settings.
    static func resolve(
        timerRunning: Bool, timerPaused: Bool, musicPlaying: Bool, musicRecentlyPaused: Bool
    ) -> LiveActivity? {
        if timerRunning { return .pomodoro }
        if musicPlaying || musicRecentlyPaused { return .music }
        if timerPaused { return .pomodoro }
        return nil
    }
}

/// What the notch is showing right now.
enum NotchPresentation: Equatable {
    case closed
    case compact(LiveActivity)
    case open
}
