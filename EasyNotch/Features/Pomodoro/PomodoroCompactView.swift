import SwiftUI

/// The timer's "live activity" beside the closed notch: a progress ring on the left wing and
/// the time left on the right one.
struct PomodoroCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(PomodoroController.self) private var pomodoro

    var body: some View {
        let engine = pomodoro.engine
        let config = pomodoro.config

        SecondsTimeline(isRunning: engine.isRunning) { now in
            switch side {
            case .leading:
                ZStack {
                    PomodoroRing(progress: engine.progress(at: now, config: config), color: engine.phase.color, lineWidth: 2.5)
                    if !engine.isRunning {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(engine.phase.color)
                    }
                }
                .frame(maxWidth: 16, maxHeight: 16)
                .aspectRatio(1, contentMode: .fit)  // shrinks in narrow wings
            case .trailing:
                Text(PomodoroClock.string(for: engine.remaining(at: now, config: config)))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)  // shrinks in narrow wings
                    .foregroundStyle(engine.isRunning ? .white : .secondary)
            }
        }
    }
}
