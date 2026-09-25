import SwiftUI

/// A circular progress ring: a faint full circle with a bright arc for the elapsed part.
struct PomodoroRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))  // start at 12 o'clock
        }
    }
}

extension PomodoroPhase {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .focus: Color(red: 1.0, green: 0.42, blue: 0.32)      // tomato
        case .shortBreak: Color(red: 0.33, green: 0.85, blue: 0.52) // green
        case .longBreak: Color(red: 0.38, green: 0.62, blue: 1.0)   // blue
        }
    }
}
