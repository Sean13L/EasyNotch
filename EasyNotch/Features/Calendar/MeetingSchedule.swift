import Foundation

/// The rules for which event is "next", how the coming days are listed, and when an event
/// shows beside the notch. Pure, tested.
nonisolated enum MeetingSchedule {
    /// One day of the agenda.
    struct Day: Equatable {
        /// Midnight at the start of the day.
        let date: Date
        let events: [Meeting]
    }

    /// A meeting's alert can start until this long after it starts (see `MeetingAlerts`), and
    /// it reads "now" for this long.
    static let showsAfterStart: TimeInterval = 5 * 60

    /// Timed meetings that haven't ended yet, soonest first.
    static func upcoming(_ meetings: [Meeting], now: Date) -> [Meeting] {
        meetings.filter { !$0.isAllDay && $0.end > now }.sorted { $0.start < $1.start }
    }

    /// The meeting to highlight: one in progress, or else the next to start.
    static func next(_ meetings: [Meeting], now: Date) -> Meeting? {
        upcoming(meetings, now: now).first
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

    /// The coming days' events that haven't ended, grouped by day, soonest first. All-day
    /// events come first in each day. `excluding` leaves out the event already highlighted.
    /// An event that began before today (a multi-day trip, say) is listed under today.
    static func agenda(
        _ meetings: [Meeting], now: Date, excluding excludedID: String? = nil, calendar: Calendar = .current
    ) -> [Day] {
        let byDay = Dictionary(grouping: meetings.filter { $0.end > now && $0.id != excludedID }) {
            calendar.startOfDay(for: max($0.start, now))
        }
        return byDay.keys.sorted().map { day in
            let events = byDay[day]!.sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.isAllDay ? a.title < b.title : a.start < b.start
            }
            return Day(date: day, events: events)
        }
    }

    /// "Today", "Tomorrow", or the weekday and date, e.g. "Wednesday, Sep 30".
    static func dayTitle(
        _ day: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        var style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.abbreviated).day()
        style.locale = locale
        return day.formatted(style)
    }

    /// "in 4m", "in 1h 5m", "now", or "ends in 20m" for one already under way. An event on a
    /// later day gets its day instead ("Tomorrow"), since "in 26h" is hard to read.
    static func relativeText(for meeting: Meeting, now: Date, calendar: Calendar = .current) -> String {
        if meeting.start > now {
            guard calendar.isDate(meeting.start, inSameDayAs: now) else {
                return dayTitle(meeting.start, now: now, calendar: calendar)
            }
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
