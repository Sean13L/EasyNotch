import AppKit
import SwiftUI

/// Connects EasyNotch to Claude Code by editing ~/.claude/settings.json (through
/// `ClaudeService`), and shows whether that's currently set up.
struct ClaudePane: View {
    let claude: ClaudeService

    /// What to show in red after a failed Connect, Disconnect, or Reconnect.
    @State private var errorMessage: String?

    /// The system red is too light to read as body text on a white settings window
    /// (about 3.6:1), so light mode uses a darker red. Dark mode keeps the system red.
    private static let errorColor = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? .systemRed
            : NSColor(srgbRed: 0.70, green: 0.10, blue: 0.10, alpha: 1)  // about 7:1 on white
    })

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Text(statusText)
                }
                LabeledContent(actionHint) {
                    Button(buttonTitle, action: perform)
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
            errorMessage = "EasyNotch couldn't start listening for Claude Code. Try again, or restart EasyNotch."
        }
    }
}
