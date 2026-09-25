import SwiftUI

/// How the notch reacts to the pointer.
struct BehaviorPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SettingSlider(
                    title: "Open after hovering for",
                    value: $settings.hoverDelay, setting: .hoverDelay, step: 0.05, unit: .seconds
                )
                SettingSlider(
                    title: "Close after leaving for",
                    value: $settings.closeDelay, setting: .closeDelay, step: 0.05, unit: .seconds
                )
                SettingSlider(
                    title: "Extra hover area around the notch",
                    value: $settings.hotZoneMargin, setting: .hotZoneMargin, step: 1, unit: .points
                )
            } header: {
                Text("Opening and closing")
            } footer: {
                Text("Short delays feel snappy; longer ones stop the notch opening when you just pass by it.")
            }

            Section {
                Toggle("Tap the trackpad when the notch opens", isOn: $settings.hapticsEnabled)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Needs a Force Touch trackpad, and you only feel it while touching the trackpad.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Behavior")
    }
}
