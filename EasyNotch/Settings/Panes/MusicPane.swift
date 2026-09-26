import SwiftUI

/// Which player to show, and whether EasyNotch may control each one.
struct MusicPane: View {
    @Bindable var settings: AppSettings
    let nowPlaying: NowPlayingService

    var body: some View {
        Form {
            Section("Players") {
                Picker("When several players are open, show", selection: $settings.musicPreferredPlayer) {
                    Text("Whichever is playing").tag("automatic")
                    ForEach(MediaPlayer.allCases, id: \.self) { player in
                        Text(player.displayName).tag(player.rawValue)
                    }
                }
                Toggle("Show what's playing beside the notch", isOn: $settings.musicInNotch)
                Picker("After pausing, keep showing it for", selection: $settings.musicPausedLinger) {
                    Text("Hide right away").tag(0.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("Until the player quits").tag(PausedTrackLinger.forever)
                }
                .disabled(!settings.musicInNotch)
            }

            Section {
                ForEach(nowPlaying.sources, id: \.player) { source in
                    PermissionRow(source: source)
                }
            } header: {
                Text("Control permission")
            } footer: {
                Text("macOS asks once per app before EasyNotch can control it. You can change this later in System Settings → Privacy & Security → Automation.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Music")
        // Update the permission status (checking never shows a prompt).
        .task {
            for source in nowPlaying.sources {
                await source.refresh()
            }
        }
    }
}

private struct PermissionRow: View {
    let source: MediaPlayerSource

    var body: some View {
        LabeledContent(source.player.displayName) {
            HStack(spacing: 8) {
                Text(status)
                    .foregroundStyle(source.permission == .granted ? .green : .secondary)
                switch source.permission {
                case .notDetermined:
                    Button("Allow…") { Task { await source.requestPermission() } }
                case .denied:
                    Button("Open System Settings") { MediaPlayerSource.openAutomationSettings() }
                case .unknown, .playerNotRunning:
                    if source.isInstalled {
                        Button("Open \(source.player.displayName)") { source.openApp() }
                    }
                case .granted:
                    EmptyView()
                }
            }
        }
    }

    private var status: String {
        if !source.isInstalled { return "Not installed" }
        switch source.permission {
        case .granted: return "Allowed"
        case .denied: return "Not allowed"
        case .notDetermined: return "Not asked yet"
        case .unknown, .playerNotRunning: return "Open the app to check"
        }
    }
}
