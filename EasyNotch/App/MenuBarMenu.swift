import SwiftUI

/// The dropdown shown when you click EasyNotch's menu-bar icon.
struct MenuBarMenu: View {
    let services: AppServices

    var body: some View {
        Text("EasyNotch \(Bundle.main.appVersion)")
        Divider()
        Button("Settings…") {
            services.showSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit EasyNotch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
