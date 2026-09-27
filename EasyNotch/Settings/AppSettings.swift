import Foundation
import Observation

/// Describes one numeric setting: where it's saved, its default, and its allowed range.
nonisolated struct NumericSetting: Sendable {
    let key: String
    let defaultValue: Double
    let range: ClosedRange<Double>

    func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

extension NumericSetting {
    // Notch
    static let hoverDelay = NumericSetting(key: "notch.hoverDelay", defaultValue: 0.15, range: 0...1)
    static let closeDelay = NumericSetting(key: "notch.closeDelay", defaultValue: 0.15, range: 0...1.5)
    static let hotZoneMargin = NumericSetting(key: "notch.hotZoneMargin", defaultValue: 8, range: 0...30)
    // The minimum open size is the smallest at which every tab's layout still fits (the Music
    // tab needs the most room). Smaller saved values are raised to it when loaded.
    static let expandedWidth = NumericSetting(key: "notch.expandedWidth", defaultValue: 640, range: 560...900)
    static let expandedHeight = NumericSetting(key: "notch.expandedHeight", defaultValue: 200, range: 190...400)
    /// Extra width on each side of the notch; 0 makes the closed notch exactly the hardware notch.
    static let compactWingWidth = NumericSetting(key: "notch.compactWingWidth", defaultValue: 64, range: 0...120)
    /// Width of the notch drawn on screens that don't have one.
    static let virtualNotchWidth = NumericSetting(key: "notch.virtualNotchWidth", defaultValue: 190, range: 120...300)

    // Keyboard shortcut (-1 means none). Stored as numbers macOS understands.
    static let shortcutKeyCode = NumericSetting(key: "shortcut.keyCode", defaultValue: -1, range: -1...511)
    static let shortcutModifiers = NumericSetting(key: "shortcut.modifiers", defaultValue: 0, range: 0...4_194_304)

    // Pomodoro (lengths in minutes)
    static let focusMinutes = NumericSetting(key: "pomodoro.focusMinutes", defaultValue: 25, range: 1...120)
    static let shortBreakMinutes = NumericSetting(key: "pomodoro.shortBreakMinutes", defaultValue: 5, range: 1...30)
    static let longBreakMinutes = NumericSetting(key: "pomodoro.longBreakMinutes", defaultValue: 15, range: 1...60)
    static let sessionsBeforeLongBreak = NumericSetting(key: "pomodoro.sessionsBeforeLongBreak", defaultValue: 4, range: 2...8)

    // Music
    /// Seconds a paused track keeps showing beside the notch; -1 means until the player quits.
    static let musicPausedLinger = NumericSetting(key: "music.pausedLingerSeconds", defaultValue: 60, range: -1...3600)

    // Shelf
    static let shelfMaxItems = NumericSetting(key: "shelf.maxItems", defaultValue: 20, range: 5...50)
    /// Remove items this many days after they were added; 0 means never.
    static let shelfAutoRemoveDays = NumericSetting(key: "shelf.autoRemoveDays", defaultValue: 0, range: 0...30)

    // Calendar
    /// Minutes before a meeting that it appears beside the notch.
    static let calendarLeadMinutes = NumericSetting(key: "calendar.leadMinutes", defaultValue: 5, range: 1...15)
    /// How many days the Calendar tab lists, counting today.
    static let calendarDaysAhead = NumericSetting(key: "calendar.daysAhead", defaultValue: 7, range: 1...14)

    // Battery
    /// Percentage at or below which a low-battery warning shows beside the notch.
    static let batteryLowThreshold = NumericSetting(key: "battery.lowThreshold", defaultValue: 10, range: 5...30)

    // System
    /// Megabytes per second above which a transfer shows beside the notch.
    static let systemTransferThreshold = NumericSetting(key: "system.transferThresholdMB", defaultValue: 5, range: 1...100)

    /// Every numeric setting, for export, import, and reset.
    static let all: [NumericSetting] = [
        hoverDelay, closeDelay, hotZoneMargin, expandedWidth, expandedHeight, compactWingWidth,
        virtualNotchWidth, shortcutKeyCode, shortcutModifiers, focusMinutes, shortBreakMinutes,
        longBreakMinutes, sessionsBeforeLongBreak, musicPausedLinger, shelfMaxItems, shelfAutoRemoveDays,
        calendarLeadMinutes, calendarDaysAhead, batteryLowThreshold, systemTransferThreshold,
    ]
}

/// Describes one on/off setting: where it's saved and its default.
nonisolated struct BoolSetting: Sendable {
    let key: String
    let defaultValue: Bool
}

extension BoolSetting {
    static let hapticsEnabled = BoolSetting(key: "notch.hapticsEnabled", defaultValue: true)
    static let openOnClick = BoolSetting(key: "notch.openOnClick", defaultValue: false)
    static let hideInFullScreen = BoolSetting(key: "notch.hideInFullScreen", defaultValue: false)
    static let autoStartBreaks = BoolSetting(key: "pomodoro.autoStartBreaks", defaultValue: true)
    static let autoStartFocus = BoolSetting(key: "pomodoro.autoStartFocus", defaultValue: false)
    static let pomodoroInNotch = BoolSetting(key: "pomodoro.showInNotch", defaultValue: true)
    static let pomodoroNotifications = BoolSetting(key: "pomodoro.notifications", defaultValue: true)
    static let pomodoroSoundEnabled = BoolSetting(key: "pomodoro.soundEnabled", defaultValue: true)
    static let musicInNotch = BoolSetting(key: "music.showInNotch", defaultValue: true)
    static let shelfOpenOnDrag = BoolSetting(key: "shelf.openOnDrag", defaultValue: true)
    static let shelfConfirmClear = BoolSetting(key: "shelf.confirmClear", defaultValue: true)
    static let shelfRemoveAfterDragOut = BoolSetting(key: "shelf.removeAfterDragOut", defaultValue: false)
    static let calendarInNotch = BoolSetting(key: "calendar.showInNotch", defaultValue: true)
    static let calendarShowAllDay = BoolSetting(key: "calendar.showAllDay", defaultValue: true)
    static let batteryChargingFlash = BoolSetting(key: "battery.chargingFlash", defaultValue: true)
    static let batteryLowWarning = BoolSetting(key: "battery.lowWarning", defaultValue: true)
    static let systemTransferInNotch = BoolSetting(key: "system.transferInNotch", defaultValue: false)

    /// Every on/off setting, for export, import, and reset.
    static let all: [BoolSetting] = [
        hapticsEnabled, openOnClick, hideInFullScreen, autoStartBreaks, autoStartFocus, pomodoroInNotch,
        pomodoroNotifications, pomodoroSoundEnabled, musicInNotch, shelfOpenOnDrag, shelfConfirmClear,
        shelfRemoveAfterDragOut, calendarInNotch, calendarShowAllDay, batteryChargingFlash, batteryLowWarning,
        systemTransferInNotch,
    ]
}

/// Describes one text setting: where it's saved, its default, and (optionally) the only values
/// it accepts.
nonisolated struct StringSetting: Sendable {
    let key: String
    let defaultValue: String
    /// Allowed values; nil means any text.
    var choices: [String]?

    func validated(_ value: String) -> String {
        guard let choices else { return value }
        return choices.contains(value) ? value : defaultValue
    }
}

extension StringSetting {
    /// "snappy", "smooth", "bouncy", or "minimal".
    static let animationStyle = StringSetting(
        key: "notch.animationStyle", defaultValue: "snappy", choices: ["snappy", "smooth", "bouncy", "minimal"]
    )
    /// "system" or a color name from `NotchAccent`.
    static let accentColor = StringSetting(
        key: "notch.accentColor", defaultValue: "system",
        choices: ["system", "blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"]
    )
    /// "builtIn", "main", or "all": which screens get a notch.
    static let displayMode = StringSetting(
        key: "notch.displayMode", defaultValue: "builtIn", choices: ["builtIn", "main", "all"]
    )
    /// "lastUsed", or a module's raw value: the tab shown when the notch opens.
    static let defaultModule = StringSetting(
        key: "notch.defaultModule", defaultValue: "lastUsed",
        choices: ["lastUsed", "music", "shelf", "pomodoro", "calendar", "battery", "system"]
    )
    /// How the keyboard shortcut is shown, e.g. "⌥⌘N".
    static let shortcutDisplay = StringSetting(key: "shortcut.display", defaultValue: "")
    /// Name of a macOS system sound.
    static let pomodoroSound = StringSetting(key: "pomodoro.sound", defaultValue: "Glass")
    /// "automatic", or a player's raw value ("spotify", "appleMusic").
    static let musicPreferredPlayer = StringSetting(
        key: "music.preferredPlayer", defaultValue: "automatic", choices: ["automatic", "spotify", "appleMusic"]
    )

    /// Every text setting, for export, import, and reset.
    static let all: [StringSetting] = [
        animationStyle, accentColor, displayMode, defaultModule, shortcutDisplay, pomodoroSound, musicPreferredPlayer,
    ]
}

/// Describes one list-of-text setting: where it's saved and its default.
nonisolated struct StringListSetting: Sendable {
    let key: String
    let defaultValue: [String]
}

extension StringListSetting {
    /// The tabs' order, as module raw values.
    static let moduleOrder = StringListSetting(
        key: "notch.moduleOrder", defaultValue: ["music", "shelf", "pomodoro", "calendar", "battery", "system"]
    )
    /// Tabs that are turned off.
    static let hiddenModules = StringListSetting(key: "notch.hiddenModules", defaultValue: [])
    /// Calendars (by identifier) left out of the Calendar tab; new calendars show by default.
    static let calendarHiddenIDs = StringListSetting(key: "calendar.hiddenCalendars", defaultValue: [])

    /// Every list setting, for export, import, and reset.
    static let all: [StringListSetting] = [moduleOrder, hiddenModules, calendarHiddenIDs]
}

/// Every user-adjustable option. Each value loads from UserDefaults (falling back to its
/// default) and saves the moment it changes; views reading it update live.
@Observable
final class AppSettings {
    // MARK: Notch behavior

    /// Seconds the pointer must rest on the notch before it opens.
    var hoverDelay = NumericSetting.hoverDelay.defaultValue { didSet { save(hoverDelay, .hoverDelay) } }
    /// Seconds the pointer can be away from the open notch before it closes.
    var closeDelay = NumericSetting.closeDelay.defaultValue { didSet { save(closeDelay, .closeDelay) } }
    /// Extra points around the notch that still count as hovering it.
    var hotZoneMargin = NumericSetting.hotZoneMargin.defaultValue { didSet { save(hotZoneMargin, .hotZoneMargin) } }
    /// A light trackpad tap when the notch opens (Force Touch trackpads only).
    var hapticsEnabled = BoolSetting.hapticsEnabled.defaultValue { didSet { save(hapticsEnabled, .hapticsEnabled) } }
    /// Open with a click instead of by hovering.
    var openOnClick = BoolSetting.openOnClick.defaultValue { didSet { save(openOnClick, .openOnClick) } }
    /// Hide the notch on a screen while an app there is full screen.
    var hideInFullScreen = BoolSetting.hideInFullScreen.defaultValue { didSet { save(hideInFullScreen, .hideInFullScreen) } }

    // MARK: Appearance

    var animationStyle = StringSetting.animationStyle.defaultValue { didSet { save(animationStyle, .animationStyle) } }
    var accentColor = StringSetting.accentColor.defaultValue { didSet { save(accentColor, .accentColor) } }

    // MARK: Notch size

    var expandedWidth = NumericSetting.expandedWidth.defaultValue { didSet { save(expandedWidth, .expandedWidth) } }
    var expandedHeight = NumericSetting.expandedHeight.defaultValue { didSet { save(expandedHeight, .expandedHeight) } }
    /// How far the notch widens on each side to show a live activity (e.g. a running timer).
    var compactWingWidth = NumericSetting.compactWingWidth.defaultValue { didSet { save(compactWingWidth, .compactWingWidth) } }

    // MARK: Displays

    var displayMode = StringSetting.displayMode.defaultValue { didSet { save(displayMode, .displayMode) } }
    var virtualNotchWidth = NumericSetting.virtualNotchWidth.defaultValue { didSet { save(virtualNotchWidth, .virtualNotchWidth) } }

    // MARK: Modules

    var moduleOrder = StringListSetting.moduleOrder.defaultValue { didSet { save(moduleOrder, .moduleOrder) } }
    var hiddenModules = StringListSetting.hiddenModules.defaultValue { didSet { save(hiddenModules, .hiddenModules) } }
    var defaultModule = StringSetting.defaultModule.defaultValue { didSet { save(defaultModule, .defaultModule) } }

    // MARK: Keyboard shortcut

    /// macOS key code of the shortcut's key, or -1 for no shortcut.
    var shortcutKeyCode = NumericSetting.shortcutKeyCode.defaultValue { didSet { save(shortcutKeyCode, .shortcutKeyCode) } }
    /// The shortcut's modifier keys, in the format macOS's hot-key API expects.
    var shortcutModifiers = NumericSetting.shortcutModifiers.defaultValue { didSet { save(shortcutModifiers, .shortcutModifiers) } }
    var shortcutDisplay = StringSetting.shortcutDisplay.defaultValue { didSet { save(shortcutDisplay, .shortcutDisplay) } }
    /// True while Settings is recording a new shortcut, so the current one is paused and the
    /// keys reach the recorder. Not saved.
    var isRecordingShortcut = false

    // MARK: Pomodoro

    var focusMinutes = NumericSetting.focusMinutes.defaultValue { didSet { save(focusMinutes, .focusMinutes) } }
    var shortBreakMinutes = NumericSetting.shortBreakMinutes.defaultValue { didSet { save(shortBreakMinutes, .shortBreakMinutes) } }
    var longBreakMinutes = NumericSetting.longBreakMinutes.defaultValue { didSet { save(longBreakMinutes, .longBreakMinutes) } }
    var sessionsBeforeLongBreak = NumericSetting.sessionsBeforeLongBreak.defaultValue { didSet { save(sessionsBeforeLongBreak, .sessionsBeforeLongBreak) } }
    var autoStartBreaks = BoolSetting.autoStartBreaks.defaultValue { didSet { save(autoStartBreaks, .autoStartBreaks) } }
    var autoStartFocus = BoolSetting.autoStartFocus.defaultValue { didSet { save(autoStartFocus, .autoStartFocus) } }
    /// Show the running timer beside the closed notch.
    var pomodoroInNotch = BoolSetting.pomodoroInNotch.defaultValue { didSet { save(pomodoroInNotch, .pomodoroInNotch) } }
    var pomodoroNotifications = BoolSetting.pomodoroNotifications.defaultValue { didSet { save(pomodoroNotifications, .pomodoroNotifications) } }
    var pomodoroSoundEnabled = BoolSetting.pomodoroSoundEnabled.defaultValue { didSet { save(pomodoroSoundEnabled, .pomodoroSoundEnabled) } }
    /// Name of a macOS system sound, e.g. "Glass".
    var pomodoroSound = StringSetting.pomodoroSound.defaultValue { didSet { save(pomodoroSound, .pomodoroSound) } }

    // MARK: Music

    /// "automatic", "spotify", or "appleMusic": which player to show when several are open.
    var musicPreferredPlayer = StringSetting.musicPreferredPlayer.defaultValue { didSet { save(musicPreferredPlayer, .musicPreferredPlayer) } }
    /// Show what's playing beside the closed notch.
    var musicInNotch = BoolSetting.musicInNotch.defaultValue { didSet { save(musicInNotch, .musicInNotch) } }
    /// Seconds a paused track keeps showing beside the notch; -1 means until the player quits.
    var musicPausedLinger = NumericSetting.musicPausedLinger.defaultValue { didSet { save(musicPausedLinger, .musicPausedLinger) } }

    // MARK: Shelf

    /// Open the notch on the Shelf tab when files are dragged near it.
    var shelfOpenOnDrag = BoolSetting.shelfOpenOnDrag.defaultValue { didSet { save(shelfOpenOnDrag, .shelfOpenOnDrag) } }
    var shelfMaxItems = NumericSetting.shelfMaxItems.defaultValue { didSet { save(shelfMaxItems, .shelfMaxItems) } }
    /// Days before items are removed automatically; 0 means never.
    var shelfAutoRemoveDays = NumericSetting.shelfAutoRemoveDays.defaultValue { didSet { save(shelfAutoRemoveDays, .shelfAutoRemoveDays) } }
    var shelfConfirmClear = BoolSetting.shelfConfirmClear.defaultValue { didSet { save(shelfConfirmClear, .shelfConfirmClear) } }
    /// Take files off the shelf once they've been dragged out and dropped somewhere.
    var shelfRemoveAfterDragOut = BoolSetting.shelfRemoveAfterDragOut.defaultValue { didSet { save(shelfRemoveAfterDragOut, .shelfRemoveAfterDragOut) } }

    // MARK: Calendar

    /// Show an upcoming meeting beside the closed notch.
    var calendarInNotch = BoolSetting.calendarInNotch.defaultValue { didSet { save(calendarInNotch, .calendarInNotch) } }
    var calendarLeadMinutes = NumericSetting.calendarLeadMinutes.defaultValue { didSet { save(calendarLeadMinutes, .calendarLeadMinutes) } }
    var calendarDaysAhead = NumericSetting.calendarDaysAhead.defaultValue { didSet { save(calendarDaysAhead, .calendarDaysAhead) } }
    var calendarShowAllDay = BoolSetting.calendarShowAllDay.defaultValue { didSet { save(calendarShowAllDay, .calendarShowAllDay) } }
    var calendarHiddenIDs = StringListSetting.calendarHiddenIDs.defaultValue { didSet { save(calendarHiddenIDs, .calendarHiddenIDs) } }

    // MARK: Battery

    /// Briefly show the charge beside the notch when a charger is connected.
    var batteryChargingFlash = BoolSetting.batteryChargingFlash.defaultValue { didSet { save(batteryChargingFlash, .batteryChargingFlash) } }
    var batteryLowWarning = BoolSetting.batteryLowWarning.defaultValue { didSet { save(batteryLowWarning, .batteryLowWarning) } }
    var batteryLowThreshold = NumericSetting.batteryLowThreshold.defaultValue { didSet { save(batteryLowThreshold, .batteryLowThreshold) } }

    // MARK: System

    /// Show big network transfers beside the notch (measures the network every 2 s).
    var systemTransferInNotch = BoolSetting.systemTransferInNotch.defaultValue { didSet { save(systemTransferInNotch, .systemTransferInNotch) } }
    var systemTransferThreshold = NumericSetting.systemTransferThreshold.defaultValue { didSet { save(systemTransferThreshold, .systemTransferThreshold) } }

    // MARK: - Storage

    @ObservationIgnored private let defaults: UserDefaults
    /// True while values are being read in, so they aren't written straight back.
    @ObservationIgnored private var isReloading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    /// Puts every option back to its default.
    func resetToDefaults() {
        allKeys.forEach(defaults.removeObject(forKey:))
        reload()
    }

    // MARK: - Export and import

    /// Every setting's current value, keyed by its storage key. Written to a file by "Export".
    func exportedValues() -> [String: Any] {
        var values: [String: Any] = [:]
        NumericSetting.all.forEach { values[$0.key] = Self.load($0, from: defaults) }
        BoolSetting.all.forEach { values[$0.key] = Self.load($0, from: defaults) }
        StringSetting.all.forEach { values[$0.key] = Self.load($0, from: defaults) }
        StringListSetting.all.forEach { values[$0.key] = Self.load($0, from: defaults) }
        return values
    }

    /// Applies values from an exported file. Unknown keys and values of the wrong type are
    /// ignored; numbers are kept in range and text limited to allowed choices. Returns how many
    /// settings were applied.
    @discardableResult
    func importValues(_ values: [String: Any]) -> Int {
        var applied = 0
        for setting in NumericSetting.all {
            // JSON's true/false also arrive as numbers; skip those. (Checking `is Bool` would
            // wrongly skip the numbers 0 and 1 too.)
            guard let number = values[setting.key] as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID()
            else { continue }
            defaults.set(setting.clamped(number.doubleValue), forKey: setting.key)
            applied += 1
        }
        for setting in BoolSetting.all {
            guard let flag = values[setting.key] as? Bool else { continue }
            defaults.set(flag, forKey: setting.key)
            applied += 1
        }
        for setting in StringSetting.all {
            guard let text = values[setting.key] as? String else { continue }
            defaults.set(setting.validated(text), forKey: setting.key)
            applied += 1
        }
        for setting in StringListSetting.all {
            guard let list = values[setting.key] as? [String] else { continue }
            defaults.set(list, forKey: setting.key)
            applied += 1
        }
        reload()
        return applied
    }

    // MARK: - Private

    private var allKeys: [String] {
        NumericSetting.all.map(\.key) + BoolSetting.all.map(\.key)
            + StringSetting.all.map(\.key) + StringListSetting.all.map(\.key)
    }

    /// Reads every option from storage (or its default).
    private func reload() {
        isReloading = true
        defer { isReloading = false }
        hoverDelay = Self.load(.hoverDelay, from: defaults)
        closeDelay = Self.load(.closeDelay, from: defaults)
        hotZoneMargin = Self.load(.hotZoneMargin, from: defaults)
        hapticsEnabled = Self.load(.hapticsEnabled, from: defaults)
        openOnClick = Self.load(.openOnClick, from: defaults)
        hideInFullScreen = Self.load(.hideInFullScreen, from: defaults)
        animationStyle = Self.load(.animationStyle, from: defaults)
        accentColor = Self.load(.accentColor, from: defaults)
        expandedWidth = Self.load(.expandedWidth, from: defaults)
        expandedHeight = Self.load(.expandedHeight, from: defaults)
        compactWingWidth = Self.load(.compactWingWidth, from: defaults)
        displayMode = Self.load(.displayMode, from: defaults)
        virtualNotchWidth = Self.load(.virtualNotchWidth, from: defaults)
        moduleOrder = Self.load(.moduleOrder, from: defaults)
        hiddenModules = Self.load(.hiddenModules, from: defaults)
        defaultModule = Self.load(.defaultModule, from: defaults)
        shortcutKeyCode = Self.load(.shortcutKeyCode, from: defaults)
        shortcutModifiers = Self.load(.shortcutModifiers, from: defaults)
        shortcutDisplay = Self.load(.shortcutDisplay, from: defaults)
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
        musicPausedLinger = Self.load(.musicPausedLinger, from: defaults)
        shelfOpenOnDrag = Self.load(.shelfOpenOnDrag, from: defaults)
        shelfMaxItems = Self.load(.shelfMaxItems, from: defaults)
        shelfAutoRemoveDays = Self.load(.shelfAutoRemoveDays, from: defaults)
        shelfConfirmClear = Self.load(.shelfConfirmClear, from: defaults)
        shelfRemoveAfterDragOut = Self.load(.shelfRemoveAfterDragOut, from: defaults)
        calendarInNotch = Self.load(.calendarInNotch, from: defaults)
        calendarLeadMinutes = Self.load(.calendarLeadMinutes, from: defaults)
        calendarDaysAhead = Self.load(.calendarDaysAhead, from: defaults)
        calendarShowAllDay = Self.load(.calendarShowAllDay, from: defaults)
        calendarHiddenIDs = Self.load(.calendarHiddenIDs, from: defaults)
        batteryChargingFlash = Self.load(.batteryChargingFlash, from: defaults)
        batteryLowWarning = Self.load(.batteryLowWarning, from: defaults)
        batteryLowThreshold = Self.load(.batteryLowThreshold, from: defaults)
        systemTransferInNotch = Self.load(.systemTransferInNotch, from: defaults)
        systemTransferThreshold = Self.load(.systemTransferThreshold, from: defaults)
    }

    private func save(_ value: Double, _ setting: NumericSetting) {
        guard !isReloading else { return }
        defaults.set(value, forKey: setting.key)
    }

    private func save(_ value: Bool, _ setting: BoolSetting) {
        guard !isReloading else { return }
        defaults.set(value, forKey: setting.key)
    }

    private func save(_ value: String, _ setting: StringSetting) {
        guard !isReloading else { return }
        defaults.set(value, forKey: setting.key)
    }

    private func save(_ value: [String], _ setting: StringListSetting) {
        guard !isReloading else { return }
        defaults.set(value, forKey: setting.key)
    }

    /// Reads a saved value, clamped into range in case an older version saved something
    /// that's no longer allowed.
    /// `double(forKey:)` and `bool(forKey:)` also understand text values, which is how
    /// command-line overrides like `-pomodoro.focusMinutes 1` arrive.
    private static func load(_ setting: NumericSetting, from defaults: UserDefaults) -> Double {
        guard defaults.object(forKey: setting.key) != nil else { return setting.defaultValue }
        return setting.clamped(defaults.double(forKey: setting.key))
    }

    private static func load(_ setting: BoolSetting, from defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: setting.key) != nil else { return setting.defaultValue }
        return defaults.bool(forKey: setting.key)
    }

    private static func load(_ setting: StringSetting, from defaults: UserDefaults) -> String {
        defaults.string(forKey: setting.key).map(setting.validated) ?? setting.defaultValue
    }

    private static func load(_ setting: StringListSetting, from defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: setting.key) ?? setting.defaultValue
    }
}
