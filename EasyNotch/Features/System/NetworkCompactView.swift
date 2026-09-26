import SwiftUI

/// A big transfer beside the closed notch: an arrow on the left, the speed on the right.
struct NetworkCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(SystemMonitor.self) private var monitor

    private var isUpload: Bool { monitor.upload > monitor.download }

    var body: some View {
        switch side {
        case .leading:
            Image(systemName: isUpload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.cyan)
        case .trailing:
            Text(SystemMath.rateText(max(monitor.download, monitor.upload)))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
