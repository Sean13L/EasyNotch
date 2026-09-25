/// Something a feature wants to show beside the closed notch (the "compact" state).
enum LiveActivity: Equatable {
    case pomodoro
    case music

    /// The tab to show when the notch opens from this activity.
    var module: NotchModule {
        switch self {
        case .pomodoro: .pomodoro
        case .music: .music
        }
    }

    /// Picks what to show when several things are going on. A running timer wins because it's
    /// time-sensitive, then playing music, then a paused timer. Each flag should already
    /// account for the user's "show beside the notch" settings.
    static func resolve(timerRunning: Bool, timerPaused: Bool, musicPlaying: Bool) -> LiveActivity? {
        if timerRunning { return .pomodoro }
        if musicPlaying { return .music }
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
