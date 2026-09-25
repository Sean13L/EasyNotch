import Foundation
import Observation

/// Describes one numeric setting: where it's saved, its default, and its allowed range.
nonisolated struct NumericSetting: Sendable {
    let key: String
    let defaultValue: Double
    let range: ClosedRange<Double>
}

extension NumericSetting {
    // Notch
    static let hoverDelay = NumericSetting(key: "notch.hoverDelay", defaultValue: 0.15, range: 0...1)
    static let closeDelay = NumericSetting(key: "notch.closeDelay", defaultValue: 0.15, range: 0...1.5)
    static let hotZoneMargin = NumericSetting(key: "notch.hotZoneMargin", defaultValue: 8, range: 0...30)
    // The minimum sizes are the smallest at which every tab's layout still fits (the Music tab
    // needs the most room). Smaller saved values are raised to these when loaded.
    static let expandedWidth = NumericSetting(key: "notch.expandedWidth", defaultValue: 640, range: 560...900)
    static let expandedHeight = NumericSetting(key: "notch.expandedHeight", defaultValue: 200, range: 190...400)
    static let compactWingWidth = NumericSetting(key: "notch.compactWingWidth", defaultValue: 64, range: 48...120)

    // Pomodoro (lengths in minutes)
    static let focusMinutes = NumericSetting(key: "pomodoro.focusMinutes", defaultValue: 25, range: 1...120)
    static let shortBreakMinutes = NumericSetting(key: "pomodoro.shortBreakMinutes", defaultValue: 5, range: 1...30)
    static let longBreakMinutes = NumericSetting(key: "pomodoro.longBreakMinutes", defaultValue: 15, range: 1...60)
    static let sessionsBeforeLongBreak = NumericSetting(key: "pomodoro.sessionsBeforeLongBreak", defaultValue: 4, range: 2...8)
}

/// Describes one on/off setting: where it's saved and its default.
nonisolated struct BoolSetting: Sendable {
    let key: String
    let defaultValue: Bool
}

extension BoolSetting {
    static let hapticsEnabled = BoolSetting(key: "notch.hapticsEnabled", defaultValue: true)
    static let autoStartBreaks = BoolSetting(key: "pomodoro.autoStartBreaks", defaultValue: true)
    static let autoStartFocus = BoolSetting(key: "pomodoro.autoStartFocus", defaultValue: false)
    static let pomodoroInNotch = BoolSetting(key: "pomodoro.showInNotch", defaultValue: true)
    static let pomodoroNotifications = BoolSetting(key: "pomodoro.notifications", defaultValue: true)
    static let pomodoroSoundEnabled = BoolSetting(key: "pomodoro.soundEnabled", defaultValue: true)
    static let musicInNotch = BoolSetting(key: "music.showInNotch", defaultValue: true)
}

/// Describes one text setting: where it's saved and its default.
nonisolated struct StringSetting: Sendable {
    let key: String
    let defaultValue: String
}

extension StringSetting {
    /// Name of a macOS system sound.
    static let pomodoroSound = StringSetting(key: "pomodoro.sound", defaultValue: "Glass")
    /// "automatic", or a player's raw value ("spotify", "appleMusic").
    static let musicPreferredPlayer = StringSetting(key: "music.preferredPlayer", defaultValue: "automatic")
}

/// Every user-adjustable option. Each value loads from UserDefaults (falling back to its
/// default) and saves the moment it changes; views reading it update live.
@Observable
final class AppSettings {
    // MARK: Notch behavior

    /// Seconds the pointer must rest on the notch before it opens.
    var hoverDelay: Double { didSet { save(hoverDelay, .hoverDelay) } }
    /// Seconds the pointer can be away from the open notch before it closes.
    var closeDelay: Double { didSet { save(closeDelay, .closeDelay) } }
    /// Extra points around the notch that still count as hovering it.
    var hotZoneMargin: Double { didSet { save(hotZoneMargin, .hotZoneMargin) } }
    /// A light trackpad tap when the notch opens (Force Touch trackpads only).
    var hapticsEnabled: Bool { didSet { save(hapticsEnabled, .hapticsEnabled) } }

    // MARK: Notch size

    var expandedWidth: Double { didSet { save(expandedWidth, .expandedWidth) } }
    var expandedHeight: Double { didSet { save(expandedHeight, .expandedHeight) } }
    /// How far the notch widens on each side to show a live activity (e.g. a running timer).
    var compactWingWidth: Double { didSet { save(compactWingWidth, .compactWingWidth) } }

    // MARK: Pomodoro

    var focusMinutes: Double { didSet { save(focusMinutes, .focusMinutes) } }
    var shortBreakMinutes: Double { didSet { save(shortBreakMinutes, .shortBreakMinutes) } }
    var longBreakMinutes: Double { didSet { save(longBreakMinutes, .longBreakMinutes) } }
    var sessionsBeforeLongBreak: Double { didSet { save(sessionsBeforeLongBreak, .sessionsBeforeLongBreak) } }
    var autoStartBreaks: Bool { didSet { save(autoStartBreaks, .autoStartBreaks) } }
    var autoStartFocus: Bool { didSet { save(autoStartFocus, .autoStartFocus) } }
    /// Show the running timer beside the closed notch.
    var pomodoroInNotch: Bool { didSet { save(pomodoroInNotch, .pomodoroInNotch) } }
    var pomodoroNotifications: Bool { didSet { save(pomodoroNotifications, .pomodoroNotifications) } }
    var pomodoroSoundEnabled: Bool { didSet { save(pomodoroSoundEnabled, .pomodoroSoundEnabled) } }
    /// Name of a macOS system sound, e.g. "Glass".
    var pomodoroSound: String { didSet { save(pomodoroSound, .pomodoroSound) } }

    // MARK: Music

    /// "automatic", "spotify", or "appleMusic": which player to show when several are open.
    var musicPreferredPlayer: String { didSet { save(musicPreferredPlayer, .musicPreferredPlayer) } }
    /// Show what's playing beside the closed notch.
    var musicInNotch: Bool { didSet { save(musicInNotch, .musicInNotch) } }

    // MARK: Storage

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hoverDelay = Self.load(.hoverDelay, from: defaults)
        closeDelay = Self.load(.closeDelay, from: defaults)
        hotZoneMargin = Self.load(.hotZoneMargin, from: defaults)
        hapticsEnabled = Self.load(.hapticsEnabled, from: defaults)
        expandedWidth = Self.load(.expandedWidth, from: defaults)
        expandedHeight = Self.load(.expandedHeight, from: defaults)
        compactWingWidth = Self.load(.compactWingWidth, from: defaults)
        focusMinutes = Self.load(.focusMinutes, from: defaults)
        shortBreakMinutes = Self.load(.shortBreakMinutes, from: defaults)
        longBreakMinutes = Self.load(.longBreakMinutes, from: defaults)
        sessionsBeforeLongBreak = Self.load(.sessionsBeforeLongBreak, from: defaults)
        autoStartBreaks = Self.load(.autoStartBreaks, from: defaults)
        autoStartFocus = Self.load(.autoStartFocus, from: defaults)
        pomodoroInNotch = Self.load(.pomodoroInNotch, from: defaults)
        pomodoroNotifications = Self.load(.pomodoroNotifications, from: defaults)
        pomodoroSoundEnabled = Self.load(.pomodoroSoundEnabled, from: defaults)
        pomodoroSound = Self.load(.pomodoroSound, from: defaults)
        musicPreferredPlayer = Self.load(.musicPreferredPlayer, from: defaults)
        musicInNotch = Self.load(.musicInNotch, from: defaults)
    }

    func resetToDefaults() {
        hoverDelay = NumericSetting.hoverDelay.defaultValue
        closeDelay = NumericSetting.closeDelay.defaultValue
        hotZoneMargin = NumericSetting.hotZoneMargin.defaultValue
        hapticsEnabled = BoolSetting.hapticsEnabled.defaultValue
        expandedWidth = NumericSetting.expandedWidth.defaultValue
        expandedHeight = NumericSetting.expandedHeight.defaultValue
        compactWingWidth = NumericSetting.compactWingWidth.defaultValue
        focusMinutes = NumericSetting.focusMinutes.defaultValue
        shortBreakMinutes = NumericSetting.shortBreakMinutes.defaultValue
        longBreakMinutes = NumericSetting.longBreakMinutes.defaultValue
        sessionsBeforeLongBreak = NumericSetting.sessionsBeforeLongBreak.defaultValue
        autoStartBreaks = BoolSetting.autoStartBreaks.defaultValue
        autoStartFocus = BoolSetting.autoStartFocus.defaultValue
        pomodoroInNotch = BoolSetting.pomodoroInNotch.defaultValue
        pomodoroNotifications = BoolSetting.pomodoroNotifications.defaultValue
        pomodoroSoundEnabled = BoolSetting.pomodoroSoundEnabled.defaultValue
        pomodoroSound = StringSetting.pomodoroSound.defaultValue
        musicPreferredPlayer = StringSetting.musicPreferredPlayer.defaultValue
        musicInNotch = BoolSetting.musicInNotch.defaultValue
    }

    private func save(_ value: Double, _ setting: NumericSetting) {
        defaults.set(value, forKey: setting.key)
    }

    private func save(_ value: Bool, _ setting: BoolSetting) {
        defaults.set(value, forKey: setting.key)
    }

    private func save(_ value: String, _ setting: StringSetting) {
        defaults.set(value, forKey: setting.key)
    }

    /// Reads a saved value, clamped into range in case an older version saved something
    /// that's no longer allowed.
    /// `double(forKey:)` and `bool(forKey:)` also understand text values, which is how
    /// command-line overrides like `-pomodoro.focusMinutes 1` arrive.
    private static func load(_ setting: NumericSetting, from defaults: UserDefaults) -> Double {
        guard defaults.object(forKey: setting.key) != nil else { return setting.defaultValue }
        let saved = defaults.double(forKey: setting.key)
        return min(max(saved, setting.range.lowerBound), setting.range.upperBound)
    }

    private static func load(_ setting: BoolSetting, from defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: setting.key) != nil else { return setting.defaultValue }
        return defaults.bool(forKey: setting.key)
    }

    private static func load(_ setting: StringSetting, from defaults: UserDefaults) -> String {
        defaults.string(forKey: setting.key) ?? setting.defaultValue
    }
}
