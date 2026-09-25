import SwiftUI

/// Redraws its content once a second while the timer runs, and not at all otherwise, so a
/// paused or idle timer costs no CPU.
struct PomodoroTimeline<Content: View>: View {
    let isRunning: Bool
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        if isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(context.date)
            }
        } else {
            content(.now)
        }
    }
}
