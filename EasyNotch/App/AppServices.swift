import Observation

/// Creates and owns the app's long-lived objects. Each is made once, here, and handed to
/// whatever needs it, so there are no hidden singletons.
final class AppServices {
    let settings = AppSettings()
    let pomodoro: PomodoroController
    let nowPlaying: NowPlayingService
    let shelf: ShelfStore
    let calendar: CalendarService
    let battery: BatteryService
    let system: SystemMonitor
    private let mouseTracker = MouseTracker()
    private let hotKey = HotKeyCenter()
    private let screenManager: ScreenManager
    private let settingsWindow: SettingsWindowController

    init() {
        pomodoro = PomodoroController(settings: settings)
        nowPlaying = NowPlayingService(settings: settings)
        shelf = ShelfStore(settings: settings)
        calendar = CalendarService(settings: settings)
        battery = BatteryService(settings: settings)
        system = SystemMonitor(settings: settings)
        screenManager = ScreenManager(
            settings: settings,
            mouseTracker: mouseTracker,
            features: NotchFeatures(
                pomodoro: pomodoro, nowPlaying: nowPlaying, shelf: shelf,
                calendar: calendar, battery: battery, system: system
            )
        )
        settingsWindow = SettingsWindowController(settings: settings, nowPlaying: nowPlaying, calendar: calendar)

        // Wire the pieces together now that they all exist.
        screenManager.onShowSettings = { [weak self] in self?.showSettings() }
        settingsWindow.onPreviewChange = { [weak self] preview in
            self?.screenManager.setPreview(preview)
        }
        hotKey.onPress = { [weak self] in self?.screenManager.toggleFromShortcut() }

        // What appears beside the closed notch. A tab that's turned off shows nothing.
        screenManager.liveActivityProvider = { [settings, pomodoro, nowPlaying, calendar, battery, system] in
            let visible = NotchModule.visible(order: settings.moduleOrder, hidden: settings.hiddenModules)
            let showTimer = settings.pomodoroInNotch && visible.contains(.pomodoro) && pomodoro.engine.isActive
            let showMusic = settings.musicInNotch && visible.contains(.music)
            let showBattery = visible.contains(.battery)
            // Each service already applies its own "show beside the notch" setting.
            return LiveActivity.resolve(.init(
                chargingFlash: showBattery && battery.isFlashing,
                meetingSoon: visible.contains(.calendar) && calendar.liveMeeting != nil,
                timerRunning: showTimer && pomodoro.engine.isRunning,
                musicPlaying: showMusic && nowPlaying.isPlaying,
                musicRecentlyPaused: showMusic && nowPlaying.showsPausedTrack,
                lowBattery: showBattery && battery.isLow,
                bigTransfer: visible.contains(.system) && system.isTransferring,
                timerPaused: showTimer && !pomodoro.engine.isRunning
            ))
        }
    }

    func start() {
        pomodoro.activate()
        nowPlaying.activate()
        calendar.activate()
        battery.activate()
        system.activate()
        screenManager.start()
        watchShortcut()
    }

    func showSettings() {
        settingsWindow.show()
    }

    /// Registers the keyboard shortcut, and again whenever it changes. It's paused while
    /// Settings records a new one.
    private func watchShortcut() {
        withObservationTracking {
            if settings.isRecordingShortcut {
                hotKey.unregister()
            } else {
                hotKey.register(
                    keyCode: Int(settings.shortcutKeyCode),
                    carbonModifiers: Int(settings.shortcutModifiers)
                )
            }
        } onChange: { [weak self] in
            // onChange fires just before the new value is stored; look on the next main-loop turn.
            Task { @MainActor [weak self] in self?.watchShortcut() }
        }
    }
}
