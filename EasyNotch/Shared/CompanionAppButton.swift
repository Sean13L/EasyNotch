import AppKit
import SwiftUI

/// A Mac app (or System Settings page) that goes with a tab, e.g. Calendar for the Calendar tab.
struct CompanionApp {
    let name: String
    let bundleID: String
    /// Opened instead of the app itself, e.g. one page of System Settings.
    var url: URL?

    static let calendar = CompanionApp(name: "Calendar", bundleID: "com.apple.iCal")
    static let activityMonitor = CompanionApp(name: "Activity Monitor", bundleID: "com.apple.ActivityMonitor")
    static let batterySettings = CompanionApp(
        name: "Battery Settings", bundleID: "com.apple.systempreferences",
        url: URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")
    )

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    func open() {
        if let url {
            NSWorkspace.shared.open(url)
        } else if let appURL {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

/// The companion app's icon; clicking it opens the app. Sits in a corner of its tab, like the
/// player's icon in the Music tab.
struct CompanionAppButton: View {
    let app: CompanionApp

    var body: some View {
        if let appURL = app.appURL {
            Button(action: app.open) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open \(app.name)")
        }
    }
}
