import SwiftUI

/// The groups of settings shown in the sidebar.
enum SettingsPane: String, CaseIterable, Identifiable {
    case behavior
    case size

    var id: Self { self }

    var title: String {
        switch self {
        case .behavior: "Behavior"
        case .size: "Size"
        }
    }

    var systemImage: String {
        switch self {
        case .behavior: "cursorarrow.motionlines"
        case .size: "arrow.up.left.and.arrow.down.right"
        }
    }
}

/// The Settings window's content: a sidebar of panes, with the selected pane on the right.
struct SettingsView: View {
    let settings: AppSettings
    /// Reports the selected pane, so the window controller can start or stop the notch preview.
    let onPaneChange: (SettingsPane) -> Void

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
            case .size: SizePane(settings: settings)
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
