/// Creates and owns the app's long-lived objects. Each is made once, here, and handed to
/// whatever needs it, so there are no hidden singletons.
final class AppServices {
    let settings = AppSettings()
    let pomodoro: PomodoroController
    private let mouseTracker = MouseTracker()
    private let screenManager: ScreenManager
    private let settingsWindow: SettingsWindowController

    init() {
        pomodoro = PomodoroController(settings: settings)
        screenManager = ScreenManager(settings: settings, mouseTracker: mouseTracker, pomodoro: pomodoro)
        settingsWindow = SettingsWindowController(settings: settings)

        // Wire the pieces together now that they all exist.
        screenManager.onShowSettings = { [weak self] in self?.showSettings() }
        settingsWindow.onPreviewChange = { [weak self] isPreviewing in
            self?.screenManager.setPreview(isPreviewing)
        }
        // What appears beside the closed notch. Phase 3 adds music here.
        screenManager.liveActivityProvider = { [settings, pomodoro] in
            settings.pomodoroInNotch && pomodoro.engine.isActive ? .pomodoro : nil
        }
    }

    func start() {
        pomodoro.activate()
        screenManager.start()
    }

    func showSettings() {
        settingsWindow.show()
    }
}
