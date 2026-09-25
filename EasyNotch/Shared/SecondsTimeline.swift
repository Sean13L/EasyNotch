import SwiftUI

/// Redraws its content once a second while something is running, and not at all otherwise, so a
/// paused timer or track costs no CPU.
struct SecondsTimeline<Content: View>: View {
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
