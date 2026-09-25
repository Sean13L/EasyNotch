/// The features that can appear as tabs in the expanded notch, in default tab order.
enum NotchModule: String, CaseIterable, Identifiable, Codable {
    case music
    case shelf
    case pomodoro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: "Music"
        case .shelf: "Shelf"
        case .pomodoro: "Pomodoro"
        }
    }

    /// SF Symbol shown on the tab.
    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .shelf: "tray.full"
        case .pomodoro: "timer"
        }
    }
}
