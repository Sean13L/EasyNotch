import SwiftUI

/// An upcoming meeting beside the closed notch: its calendar color on the left, "in 4m" or "now"
/// on the right.
struct MeetingCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(CalendarService.self) private var calendar

    var body: some View {
        if let meeting = calendar.liveMeeting {
            switch side {
            case .leading:
                Image(systemName: meeting.joinURL == nil ? "calendar" : "video.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(meeting.color.swiftUIColor)
            case .trailing:
                TimelineView(.everyMinute) { context in
                    Text(MeetingSchedule.relativeText(for: meeting, now: context.date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }
}
