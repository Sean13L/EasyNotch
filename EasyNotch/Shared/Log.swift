import OSLog

/// App-wide loggers, one category per area. View them live in Console.app
/// (search "easynotch") or with:
///   /usr/bin/log stream --level debug --predicate 'subsystem == "com.seanl.easynotch"'
/// `.debug`/`.info` messages are only visible while streaming; `.notice` and above are
/// also saved, so past ones show up in `/usr/bin/log show`.
///
/// `nonisolated` so background actors can log without hopping to the main actor.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.seanl.easynotch"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let notch = Logger(subsystem: subsystem, category: "notch")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let pomodoro = Logger(subsystem: subsystem, category: "pomodoro")
    static let music = Logger(subsystem: subsystem, category: "music")
    static let shelf = Logger(subsystem: subsystem, category: "shelf")
}
