import SwiftUI

/// When the battery shows beside the notch.
struct BatteryPane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Flash the charge when you plug in", isOn: $settings.batteryChargingFlash)
            } footer: {
                Text("A bolt and the percentage appear beside the notch for a few seconds, like on an iPhone.")
            }

            Section {
                Toggle("Warn when the battery is low", isOn: $settings.batteryLowWarning)
                SettingSlider(
                    title: "Warn at or below",
                    value: $settings.batteryLowThreshold, setting: .batteryLowThreshold, step: 1, unit: .count("%")
                )
                .disabled(!settings.batteryLowWarning)
            } footer: {
                Text("A red battery shows beside the notch until you open the notch or plug in.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Battery")
    }
}
