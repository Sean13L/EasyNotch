import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Starting at login, the keyboard shortcut, and moving settings between Macs.
struct GeneralPane: View {
    @Bindable var settings: AppSettings

    @State private var loginStatus = LoginItem.status
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open EasyNotch when you log in", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: setLaunchAtLogin
                ))
                if loginStatus == .requiresApproval {
                    LabeledContent("macOS needs you to allow it in Login Items.") {
                        Button("Open Login Items") { LoginItem.openSystemSettings() }
                    }
                    .font(.callout)
                }
            } header: {
                Text("Startup")
            }

            Section {
                LabeledContent("Open or close the notch") {
                    ShortcutRecorder(settings: settings)
                }
            } header: {
                Text("Keyboard shortcut")
            } footer: {
                Text("Works from any app. The notch opens on the screen with the pointer and stays open until you press the shortcut again, click elsewhere, or move the pointer into it and away.")
            }

            Section {
                HStack {
                    Button("Export Settings…", action: exportSettings)
                    Button("Import Settings…", action: importSettings)
                }
                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Back up or move your settings")
            } footer: {
                Text("Saves every option to a file you can import later or on another Mac. Your shelf files and timer aren't included.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear { loginStatus = LoginItem.status }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            message = "Couldn't change “open at login”: \(error.localizedDescription)"
        }
        loginStatus = LoginItem.status
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "EasyNotch Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: settings.exportedValues(), options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
            message = "Exported to \(url.lastPathComponent)."
        } catch {
            message = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            message = "That file isn't an EasyNotch settings file."
            return
        }
        let count = settings.importValues(values)
        message = count == 0
            ? "No EasyNotch settings were found in that file."
            : "Imported \(count) settings from \(url.lastPathComponent)."
    }
}
