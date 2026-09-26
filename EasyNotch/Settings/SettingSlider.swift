import SwiftUI

/// A labeled slider for one `NumericSetting`, showing its current value and unit.
struct SettingSlider: View {
    enum Unit {
        case seconds
        case points
        case minutes
        /// A plain count, e.g. "4 sessions". The associated value is the plural noun.
        case count(String)
    }

    let title: String
    @Binding var value: Double
    let setting: NumericSetting
    let step: Double
    let unit: Unit
    /// Called with true when the user starts dragging, and false when they let go.
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: setting.range, step: step, onEditingChanged: onEditingChanged)
                .labelsHidden()
        }
    }

    private var formattedValue: String {
        let whole = Int(value.rounded())
        switch unit {
        case .seconds: return value.formatted(.number.precision(.fractionLength(2))) + " s"
        case .points: return "\(whole) pt"
        case .minutes: return "\(whole) min"
        case let .count(noun): return "\(whole) \(noun)"
        }
    }
}
