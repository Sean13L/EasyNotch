import SwiftUI

/// Which screens get a notch.
struct DisplaysPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Show the notch on", selection: $settings.displayMode) {
                    Text("This Mac's own screen").tag("builtIn")
                    Text("The main screen (the one with the Dock)").tag("main")
                    Text("All screens").tag("all")
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Screens without a notch get a virtual one: a black notch shape at the top center that works just like the real thing.")
            }

            Section {
                SettingSlider(
                    title: "Width",
                    value: $settings.virtualNotchWidth, setting: .virtualNotchWidth, step: 5, unit: .points
                )
            } header: {
                Text("Virtual notch")
            } footer: {
                Text("Its height matches the menu bar on that screen.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Displays")
    }
}
