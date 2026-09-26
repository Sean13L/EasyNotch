import Foundation

/// The rules for which meeting is "next" and when it shows beside the notch. Pure, tested.
nonisolated enum MeetingSchedule {
    /// A meeting keeps showing beside the notch this long after it starts, so late joiners
    /// can still reach the Join button in one hover.
    static let showsAfterStart: TimeInterval = 5 * 60

    /// Timed meetings that haven't ended yet, soonest first.
    static func upcoming(_ meetings: [Meeting], now: Date) -> [Meeting] {
        meetings.filter { !$0.isAllDay && $0.end > now }.sorted { $0.start < $1.start }
    }

    /// The meeting to highlight: one in progress, or else the next to start.
    static func next(_ meetings: [Meeting], now: Date) -> Meeting? {
        upcoming(meetings, now: now).first
    }

    /// The meeting to show beside the closed notch: starting within `lead`, or started less than
    /// `showsAfterStart` ago.
    static func liveMeeting(_ meetings: [Meeting], now: Date, lead: TimeInterval) -> Meeting? {
        upcoming(meetings, now: now).first { meeting in
            meeting.start - lead <= now && now < meeting.start + showsAfterStart
        }
    }

    /// The next moment something could change (a meeting's window opening or closing, or a
    /// meeting ending), so the app can wake exactly then instead of checking every minute.
    static func nextChange(_ meetings: [Meeting], now: Date, lead: TimeInterval) -> Date? {
        meetings
            .filter { !$0.isAllDay }
            .flatMap { [$0.start - lead, $0.start, $0.start + showsAfterStart, $0.end] }
            .filter { $0 > now }
            .min()
    }

    /// "in 4m", "in 1h 5m", "now", or "ends in 20m" for one already under way.
    static func relativeText(for meeting: Meeting, now: Date) -> String {
        if meeting.start > now {
            return "in " + shortDuration(meeting.start.timeIntervalSince(now))
        }
        if now < meeting.start + showsAfterStart { return "now" }
        return "ends in " + shortDuration(meeting.end.timeIntervalSince(now))
    }

    /// "4m", "1h 5m", "2h". Rounds up, so a meeting 30 seconds away says "1m", not "0m".
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let (hours, rest) = (minutes / 60, minutes % 60)
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
