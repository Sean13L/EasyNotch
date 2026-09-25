import SwiftUI

/// Entry point. EasyNotch is an agent app (no Dock icon), so its only scene is the
/// menu-bar icon. The notch window itself is AppKit and gets created by `AppDelegate`.
@main
struct EasyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("EasyNotch", systemImage: "menubar.rectangle") {
            MenuBarMenu(services: appDelegate.services)
        }
    }
}
