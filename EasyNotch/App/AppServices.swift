/// Creates and owns the app's long-lived objects. Each is made once, here, and handed to
/// whatever needs it, so there are no hidden singletons.
final class AppServices {
    let settings = AppSettings()
    private let mouseTracker = MouseTracker()
    private let screenManager: ScreenManager
    private let settingsWindow: SettingsWindowController

    init() {
        screenManager = ScreenManager(settings: settings, mouseTracker: mouseTracker)
        settingsWindow = SettingsWindowController(settings: settings)

        // Wire the pieces together now that they all exist.
        screenManager.onShowSettings = { [weak self] in self?.showSettings() }
        settingsWindow.onPreviewChange = { [weak self] isPreviewing in
            self?.screenManager.setPreview(isPreviewing)
        }
    }

    func start() {
        screenManager.start()
    }

    func showSettings() {
        settingsWindow.show()
    }
}
