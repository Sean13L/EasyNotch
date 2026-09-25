import SwiftUI

/// The dropdown shown when you click EasyNotch's menu-bar icon.
struct MenuBarMenu: View {
    var body: some View {
        Text("EasyNotch \(Bundle.main.appVersion)")
        Divider()
        Button("Quit EasyNotch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
