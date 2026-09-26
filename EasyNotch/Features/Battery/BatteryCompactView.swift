import SwiftUI

/// The battery beside the closed notch: a green bolt and the charge for a few seconds after
/// plugging in, or a red battery while it's low.
struct BatteryCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(BatteryService.self) private var battery

    var body: some View {
        if let snapshot = battery.snapshot {
            let color: Color = battery.isFlashing ? .green : .red
            switch side {
            case .leading:
                Image(systemName: battery.isFlashing ? "bolt.fill" : snapshot.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: battery.isFlashing)
            case .trailing:
                Text("\(snapshot.percent)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(color)
            }
        }
    }
}
