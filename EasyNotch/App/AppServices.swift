/// Creates and owns the app's long-lived objects. Each is made once, here, and handed to
/// whatever needs it, so there are no hidden singletons.
final class AppServices {
    let settings = AppSettings()
    let pomodoro: PomodoroController
    let nowPlaying: NowPlayingService
    let shelf: ShelfStore
    private let mouseTracker = MouseTracker()
    private let screenManager: ScreenManager
    private let settingsWindow: SettingsWindowController

    init() {
        pomodoro = PomodoroController(settings: settings)
        nowPlaying = NowPlayingService(settings: settings)
        shelf = ShelfStore(settings: settings)
        screenManager = ScreenManager(
            settings: settings,
            mouseTracker: mouseTracker,
            features: NotchFeatures(pomodoro: pomodoro, nowPlaying: nowPlaying, shelf: shelf)
        )
        settingsWindow = SettingsWindowController(settings: settings, nowPlaying: nowPlaying)

        // Wire the pieces together now that they all exist.
        screenManager.onShowSettings = { [weak self] in self?.showSettings() }
        settingsWindow.onPreviewChange = { [weak self] preview in
            self?.screenManager.setPreview(preview)
        }
        // What appears beside the closed notch.
        screenManager.liveActivityProvider = { [settings, pomodoro, nowPlaying] in
            let showTimer = settings.pomodoroInNotch && pomodoro.engine.isActive
            return LiveActivity.resolve(
                timerRunning: showTimer && pomodoro.engine.isRunning,
                timerPaused: showTimer && !pomodoro.engine.isRunning,
                musicPlaying: settings.musicInNotch && nowPlaying.isPlaying,
                musicRecentlyPaused: settings.musicInNotch && nowPlaying.showsPausedTrack
            )
        }
    }

    func start() {
        pomodoro.activate()
        nowPlaying.activate()
        screenManager.start()
    }

    func showSettings() {
        settingsWindow.show()
    }
}
