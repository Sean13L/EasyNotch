import SwiftUI

/// The groups of settings shown in the sidebar.
enum SettingsPane: String, CaseIterable, Identifiable {
    case behavior
    case size
    case music
    case pomodoro

    var id: Self { self }

    var title: String {
        switch self {
        case .behavior: "Behavior"
        case .size: "Size"
        case .music: "Music"
        case .pomodoro: "Pomodoro"
        }
    }

    var systemImage: String {
        switch self {
        case .behavior: "cursorarrow.motionlines"
        case .size: "arrow.up.left.and.arrow.down.right"
        case .music: "music.note"
        case .pomodoro: "timer"
        }
    }
}

/// The Settings window's content: a sidebar of panes, with the selected pane on the right.
struct SettingsView: View {
    let settings: AppSettings
    let nowPlaying: NowPlayingService
    /// Reports the selected pane, so the window controller can start or stop the notch preview.
    let onPaneChange: (SettingsPane) -> Void
    /// Reports which notch shape the Size pane wants to preview.
    let onSizePreviewChange: (SizePreview) -> Void

    @State private var selection: SettingsPane? = .behavior
    @State private var isConfirmingReset = false

    private var pane: SettingsPane { selection ?? .behavior }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
            }
            .navigationSplitViewColumnWidth(170)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                Button("Restore Defaults…") { isConfirmingReset = true }
                    .buttonStyle(.link)
                    .padding(.bottom, 12)
            }
        } detail: {
            switch pane {
            case .behavior: BehaviorPane(settings: settings)
            case .size: SizePane(settings: settings, onPreviewChange: onSizePreviewChange)
            case .music: MusicPane(settings: settings, nowPlaying: nowPlaying)
            case .pomodoro: PomodoroPane(settings: settings)
            }
        }
        .frame(minWidth: 600, minHeight: 380)
        .onChange(of: pane, initial: true) { _, newPane in
            onPaneChange(newPane)
        }
        .confirmationDialog("Restore all settings to their defaults?", isPresented: $isConfirmingReset) {
            Button("Restore Defaults", role: .destructive) {
                settings.resetToDefaults()
                Log.settings.notice("Settings restored to defaults")
            }
        }
    }
}
