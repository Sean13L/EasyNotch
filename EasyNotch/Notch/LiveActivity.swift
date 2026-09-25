/// Something a feature wants to show beside the closed notch (the "compact" state).
enum LiveActivity: Equatable {
    case pomodoro

    /// The tab to show when the notch opens from this activity.
    var module: NotchModule {
        switch self {
        case .pomodoro: .pomodoro
        }
    }
}

/// What the notch is showing right now.
enum NotchPresentation: Equatable {
    case closed
    case compact(LiveActivity)
    case open
}
