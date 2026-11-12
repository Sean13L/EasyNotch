import AppKit
import SwiftUI

/// Connects EasyNotch to Claude Code by editing ~/.claude/settings.json (through
/// `ClaudeService`), and shows whether that's currently set up.
struct ClaudePane: View {
    let claude: ClaudeService

    /// What to show in red after a failed Connect, Disconnect, or Reconnect.
    @State private var errorMessage: String?

    /// Running from a translocated copy (see `ClaudeSetup.isTranslocated`): Connect and
    /// Reconnect would point Claude Code at a path that disappears.
    private let isTranslocated = ClaudeSetup.isTranslocated(bundlePath: Bundle.main.bundleURL.path)

    /// Connect and Reconnect are off while translocated; Disconnect always works.
    private var actionDisabled: Bool {
        isTranslocated && claude.setupStatus != .connected
    }

    /// The system reds miss AA (4.5:1) as body text on the grouped Form's row fill, so both
    /// modes use a custom red. Ratios are computed from WCAG relative luminance:
    /// - Light: sRGB(0.70, 0.10, 0.10), luminance 0.104, on a white row (1.0): about 6.8:1.
    ///   (System red is about 3.6:1 there.)
    /// - Dark: sRGB(1.0, 0.55, 0.50), luminance 0.416, on the dark row fill (about
    ///   #2C2C2E to #323232, luminance 0.025 to 0.032): about 5.7:1 to 6.2:1.
    ///   (Dark system red, luminance 0.258, is only about 3.8:1 to 4.1:1 there.)
    private static let errorColor = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 1.0, green: 0.55, blue: 0.50, alpha: 1)
            : NSColor(srgbRed: 0.70, green: 0.10, blue: 0.10, alpha: 1)
    })

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Text(statusText)
                }
                LabeledContent(actionHint) {
                    Button(buttonTitle, action: perform)
                        .disabled(actionDisabled)
                }
                if actionDisabled {
                    Text("Move EasyNotch to your Applications folder before connecting Claude Code.")
                        .foregroundStyle(Self.errorColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Self.errorColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } footer: {
                Text("Changes apply to Claude Code sessions you start after connecting. Your settings are backed up to settings.json.easynotch-backup. Key order and spacing in settings.json may change.")
            }

            Section {
                Text("To show or hide the Claude tab in the notch, use the Modules pane.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Claude Code")
    }

    private var statusText: String {
        switch claude.setupStatus {
        case .disconnected: "Not connected"
        case .connected: "Connected"
        case .needsReconnect: "EasyNotch moved — reconnect"
        }
    }

    private var buttonTitle: String {
        switch claude.setupStatus {
        case .disconnected: "Connect"
        case .connected: "Disconnect"
        case .needsReconnect: "Reconnect"
        }
    }

    /// The row's label, so the button has a visible and accessible description.
    private var actionHint: String {
        switch claude.setupStatus {
        case .disconnected: "Show Claude Code permission requests in the notch."
        case .connected: "Stop showing Claude Code requests in the notch."
        case .needsReconnect: "Point Claude Code at this copy of EasyNotch."
        }
    }

    private func perform() {
        do {
            switch claude.setupStatus {
            case .connected: try claude.disconnect()
            case .disconnected, .needsReconnect: try claude.connect()
            }
            errorMessage = nil
        } catch ClaudeSetup.SetupError.unreadableSettings {
            errorMessage = "Your Claude settings file couldn't be read, so EasyNotch left it unchanged."
        } catch {
            // Log the error type only; its description could contain file paths.
            Log.claude.error("Claude connect/disconnect failed: \(String(describing: type(of: error)), privacy: .public)")
            errorMessage = "EasyNotch couldn't start listening for Claude Code. Disconnect and connect again, or restart EasyNotch."
        }
    }
}
