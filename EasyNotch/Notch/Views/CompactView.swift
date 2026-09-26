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
                .clipped()  // very narrow wings crop their content instead of spilling over
            Color.clear.frame(width: notchWidth)
            trailingWing
                .frame(maxWidth: .infinity)
                .clipped()
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var leadingWing: some View {
        switch activity {
        case .pomodoro: PomodoroCompactView(side: .leading)
        case .music: MusicCompactView(side: .leading)
        case .placeholder: PlaceholderWing()
        }
    }

    @ViewBuilder private var trailingWing: some View {
        switch activity {
        case .pomodoro: PomodoroCompactView(side: .trailing)
        case .music: MusicCompactView(side: .trailing)
        case .placeholder: PlaceholderWing()
        }
    }
}

/// A faint bar spanning the wing, so its width is easy to judge while previewing it.
private struct PlaceholderWing: View {
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .frame(height: 6)
            .padding(.horizontal, 8)
    }
}
