import SwiftUI

/// The optional big-transfer indicator.
struct SystemPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show big downloads and uploads beside the notch", isOn: $settings.systemTransferInNotch)
                SettingSlider(
                    title: "When faster than",
                    value: $settings.systemTransferThreshold, setting: .systemTransferThreshold,
                    step: 1, unit: .count("MB/s")
                )
                .disabled(!settings.systemTransferInNotch)
            } footer: {
                Text("When this is on, EasyNotch checks network speed every 2 seconds. When it's off, the System tab only measures while it's open.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("System")
    }
}
