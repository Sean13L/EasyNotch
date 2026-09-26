import SwiftUI

/// How the file shelf behaves.
struct ShelfPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Open the notch when dragging files near it", isOn: $settings.shelfOpenOnDrag)
            } footer: {
                Text("When this is off, hover the notch first, then drop the files.")
            }

            Section("Keeping files") {
                SettingSlider(
                    title: "Keep at most",
                    value: $settings.shelfMaxItems, setting: .shelfMaxItems, step: 1, unit: .count("files")
                )
                Picker("Remove files automatically", selection: $settings.shelfAutoRemoveDays) {
                    Text("Never").tag(0.0)
                    Text("After 1 day").tag(1.0)
                    Text("After 1 week").tag(7.0)
                    Text("After 30 days").tag(30.0)
                }
                Toggle("Ask before clearing the shelf", isOn: $settings.shelfConfirmClear)
                Toggle("Remove files after dragging them out", isOn: $settings.shelfRemoveAfterDragOut)
            }

            Section {
                Text("The shelf keeps links to your files; nothing is copied or moved. A file you rename or move stays on the shelf, and one you delete shows as missing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Button("Open Files & Folders Settings") {
                        NSWorkspace.shared.open(ShelfStore.filesAndFoldersSettingsURL)
                    }
                } label: {
                    Text("Downloads, Desktop and Documents")
                    Text("macOS asks once before EasyNotch can reopen files from these folders. If you said no, their files show \"No access\"; turn access on here.")
                }
            } header: {
                Text("Protected folders")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shelf")
    }
}
