import AppKit

/// Handles app lifecycle events. From Phase 1 on, this is where the notch windows and
/// shared services get created at launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("EasyNotch \(Bundle.main.appVersion, privacy: .public) launched")
    }
}
