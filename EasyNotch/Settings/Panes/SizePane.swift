import SwiftUI

/// How big the notch gets when it opens.
struct SizePane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SettingSlider(
                    title: "Width",
                    value: $settings.expandedWidth, setting: .expandedWidth, step: 10, unit: .points
                )
                SettingSlider(
                    title: "Height",
                    value: $settings.expandedHeight, setting: .expandedHeight, step: 10, unit: .points
                )
            } header: {
                Text("Expanded notch")
            } footer: {
                Text("The notch stays open while this pane is showing, so you can watch it change.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Size")
    }
}
