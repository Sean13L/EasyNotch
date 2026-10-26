import SwiftUI

/// The timer's alert beside the closed notch, shown when a focus or break ends. A bouncing
/// bell on the left wing and "Done" on the right, until the user opens the notch.
struct PomodoroAlertView: View {
    let side: PomodoroCompactView.Side

    @Environment(PomodoroController.self) private var pomodoro

    var body: some View {
        switch side {
        case .leading:
            Image(systemName: "bell.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.orange)
                .phaseAnimator([1.0, 0.2]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.4) }
                .frame(maxWidth: 16, maxHeight: 16)
        case .trailing:
            Text(pomodoro.finishedPhase == .focus ? "Focus done" : "Break over")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.5)  // shrinks in narrow wings
                .phaseAnimator([1.0, 0.2]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.4) }
        }
    }
}
