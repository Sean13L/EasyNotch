import SwiftUI

/// A labeled slider for one `NumericSetting`, showing its current value and unit.
struct SettingSlider: View {
    enum Unit {
        case seconds
        case points
    }

    let title: String
    @Binding var value: Double
    let setting: NumericSetting
    let step: Double
    let unit: Unit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: setting.range, step: step)
                .labelsHidden()
        }
    }

    private var formattedValue: String {
        switch unit {
        case .seconds: value.formatted(.number.precision(.fractionLength(2))) + " s"
        case .points: "\(Int(value.rounded())) pt"
        }
    }
}
