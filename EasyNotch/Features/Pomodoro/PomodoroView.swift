import SwiftUI

/// The Pomodoro tab in the open notch: a ring with the time left, the current phase, session
/// dots, today's count, and the controls.
struct PomodoroView: View {
    @Environment(PomodoroController.self) private var pomodoro

    var body: some View {
        let engine = pomodoro.engine
        let config = pomodoro.config

        PomodoroTimeline(isRunning: engine.isRunning) { now in
            HStack(spacing: 32) {
                ZStack {
                    PomodoroRing(progress: engine.progress(at: now, config: config), color: engine.phase.color, lineWidth: 6)
                    VStack(spacing: 2) {
                        Text(PomodoroClock.string(for: engine.remaining(at: now, config: config)))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        if let status = statusText(engine.status) {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 10) {
                    Label(engine.phase.title, systemImage: engine.phase.systemImage)
                        .font(.headline)
                        .foregroundStyle(engine.phase.color)
                    SessionDots(
                        filled: engine.sessionsCompletedInCycle(config: config),
                        total: config.sessionsBeforeLongBreak,
                        color: PomodoroPhase.focus.color
                    )
                    Text("Today: ^[\(pomodoro.sessionsToday) session](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ControlButton(
                            systemImage: engine.isRunning ? "pause.fill" : "play.fill",
                            help: primaryHelp(engine.status),
                            tint: engine.phase.color,
                            isPrimary: true,
                            action: pomodoro.startPauseOrResume
                        )
                        ControlButton(systemImage: "forward.end.fill", help: "Skip to the next phase", action: pomodoro.skip)
                        ControlButton(systemImage: "arrow.counterclockwise", help: "Reset", action: pomodoro.reset)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 36)
        }
    }

    private func statusText(_ status: PomodoroEngine.Status) -> String? {
        switch status {
        case .idle: "Ready"
        case .paused: "Paused"
        case .running: nil
        }
    }

    private func primaryHelp(_ status: PomodoroEngine.Status) -> String {
        switch status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }
}

/// ●●○○ — focus sessions done in the current cycle.
private struct SessionDots: View {
    let filled: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(index < filled ? color : .white.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

private struct ControlButton: View {
    let systemImage: String
    let help: String
    var tint: Color = .white
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isPrimary ? 15 : 12, weight: .semibold))
                .foregroundStyle(isPrimary ? .black : .white)
                .frame(width: isPrimary ? 40 : 30, height: isPrimary ? 40 : 30)
                .background(isPrimary ? tint : .white.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
