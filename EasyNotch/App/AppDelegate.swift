import AppKit

/// Handles app lifecycle events and owns the app's services.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let services = AppServices()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("EasyNotch \(Bundle.main.appVersion, privacy: .public) launched")

        // Unit tests run inside the app; don't put notch windows on screen during tests.
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isRunningTests else { return }
        services.start()

        #if DEBUG
        // Development shortcut: open EasyNotch.app --args -OpenSettingsOnLaunch YES
        if UserDefaults.standard.bool(forKey: "OpenSettingsOnLaunch") {
            services.showSettings()
        }
        #endif
    }
}
