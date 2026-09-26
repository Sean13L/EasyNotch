import SwiftUI

/// The groups of settings shown in the sidebar.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case behavior
    case appearance
    case size
    case displays
    case modules
    case music
    case shelf
    case pomodoro
    case calendar
    case battery
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .behavior: "Behavior"
        case .appearance: "Appearance"
        case .size: "Size"
        case .displays: "Displays"
        case .modules: "Modules"
        case .music: "Music"
        case .shelf: "Shelf"
        case .pomodoro: "Pomodoro"
        case .calendar: "Calendar"
        case .battery: "Battery"
        case .system: "System"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .behavior: "cursorarrow.motionlines"
        case .appearance: "paintpalette"
        case .size: "arrow.up.left.and.arrow.down.right"
        case .displays: "display.2"
        case .modules: "square.grid.2x2"
        case .music: "music.note"
        case .shelf: "tray.full"
        case .pomodoro: "timer"
        case .calendar: "calendar"
        case .battery: "battery.75percent"
        case .system: "gauge.with.dots.needle.33percent"
        }
    }
}

/// The Settings window's content: a sidebar of panes, with the selected pane on the right.
struct SettingsView: View {
    let settings: AppSettings
    let nowPlaying: NowPlayingService
    let calendar: CalendarService
    /// Reports the selected pane, so the window controller can start or stop the notch preview.
    let onPaneChange: (SettingsPane) -> Void
    /// Reports which notch shape the Size pane wants to preview.
    let onSizePreviewChange: (SizePreview) -> Void

    @State private var selection: SettingsPane? = .general
    @State private var isConfirmingReset = false

    private var pane: SettingsPane { selection ?? .general }

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
            case .general: GeneralPane(settings: settings)
            case .behavior: BehaviorPane(settings: settings)
            case .appearance: AppearancePane(settings: settings)
            case .displays: DisplaysPane(settings: settings)
            case .modules: ModulesPane(settings: settings)
            case .size: SizePane(settings: settings, onPreviewChange: onSizePreviewChange)
            case .music: MusicPane(settings: settings, nowPlaying: nowPlaying)
            case .shelf: ShelfPane(settings: settings)
            case .calendar: CalendarPane(settings: settings, calendar: calendar)
            case .battery: BatteryPane(settings: settings)
            case .system: SystemPane(settings: settings)
            case .pomodoro: PomodoroPane(settings: settings)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
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
