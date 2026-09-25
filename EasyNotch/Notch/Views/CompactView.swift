import SwiftUI

/// The closed notch with "wings": the live activity's content on the left and right of the
/// notch, with a gap in the middle where the hardware notch hides everything.
struct CompactView: View {
    let activity: LiveActivity
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leadingWing
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: notchWidth)
            trailingWing
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var leadingWing: some View {
        switch activity {
        case .pomodoro: PomodoroCompactView(side: .leading)
        }
    }

    @ViewBuilder private var trailingWing: some View {
        switch activity {
        case .pomodoro: PomodoroCompactView(side: .trailing)
        }
    }
}
