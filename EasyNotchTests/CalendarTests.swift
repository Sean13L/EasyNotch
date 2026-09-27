import Foundation
import Testing
@testable import EasyNotch

struct CalendarTests {
    /// Saturday, May 9, 2026, 06:13 UTC.
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let minute: TimeInterval = 60
    let hour: TimeInterval = 3600
    /// A fixed time zone, so "today" is the same on every Mac that runs the tests.
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func meeting(_ id: String, startsIn start: TimeInterval, lasts length: TimeInterval = 30 * 60, allDay: Bool = false) -> Meeting {
        Meeting(
            id: id, title: id, start: t0 + start, end: t0 + start + length, isAllDay: allDay,
            color: .init(red: 0, green: 0.5, blue: 1), joinURL: nil
        )
    }

    // MARK: - Schedule

    @Test func nextSkipsFinishedAndAllDayEvents() {
        let meetings = [
            meeting("done", startsIn: -60 * minute),
            meeting("holiday", startsIn: -8 * 3600, lasts: 24 * 3600, allDay: true),
            meeting("later", startsIn: 90 * minute),
            meeting("soon", startsIn: 12 * minute),
        ]
        #expect(MeetingSchedule.next(meetings, now: t0)?.id == "soon")
        #expect(MeetingSchedule.upcoming(meetings, now: t0).map(\.id) == ["soon", "later"])
    }

    @Test func aMeetingInProgressIsStillNext() {
        let meetings = [meeting("ongoing", startsIn: -10 * minute), meeting("after", startsIn: 60 * minute)]
        #expect(MeetingSchedule.next(meetings, now: t0)?.id == "ongoing")
    }

    @Test func theNotchShowsAMeetingFromTheLeadTimeUntilFiveMinutesIn() {
        let meetings = [meeting("standup", startsIn: 10 * minute)]
        let lead = 5 * minute
        #expect(MeetingSchedule.liveMeeting(meetings, now: t0, lead: lead) == nil)  // 10 min away
        #expect(MeetingSchedule.liveMeeting(meetings, now: t0 + 5 * minute, lead: lead)?.id == "standup")
        #expect(MeetingSchedule.liveMeeting(meetings, now: t0 + 14 * minute, lead: lead)?.id == "standup")  // 4 min in
        #expect(MeetingSchedule.liveMeeting(meetings, now: t0 + 15 * minute, lead: lead) == nil)  // 5 min in
    }

    @Test func itWakesAtTheNextMomentAnythingChanges() {
        let meetings = [meeting("standup", startsIn: 10 * minute)]
        let lead = 5 * minute
        #expect(MeetingSchedule.nextChange(meetings, now: t0, lead: lead) == t0 + 5 * minute)  // window opens
        #expect(MeetingSchedule.nextChange(meetings, now: t0 + 6 * minute, lead: lead) == t0 + 10 * minute)  // starts
        #expect(MeetingSchedule.nextChange(meetings, now: t0 + 16 * minute, lead: lead) == t0 + 40 * minute)  // ends
        #expect(MeetingSchedule.nextChange(meetings, now: t0 + 41 * minute, lead: lead) == nil)
    }

    @Test func relativeTimesAreShortAndRoundUp() {
        let standup = meeting("standup", startsIn: 4 * minute)
        #expect(MeetingSchedule.relativeText(for: standup, now: t0, calendar: utc) == "in 4m")
        #expect(MeetingSchedule.relativeText(for: standup, now: t0 + 3.5 * minute, calendar: utc) == "in 1m")  // 30 s away
        #expect(MeetingSchedule.relativeText(for: standup, now: t0 + 5 * minute, calendar: utc) == "now")
        #expect(MeetingSchedule.relativeText(for: standup, now: t0 + 20 * minute, calendar: utc) == "ends in 14m")
        #expect(MeetingSchedule.shortDuration(65 * minute) == "1h 5m")
        #expect(MeetingSchedule.shortDuration(120 * minute) == "2h")
    }

    /// An all-day event from midnight `dayOffset` days from `t0`, lasting `days` days.
    func allDay(_ id: String, dayOffset: Int, days: Int = 1) -> Meeting {
        let start = utc.date(byAdding: .day, value: dayOffset, to: utc.startOfDay(for: t0))!
        let end = utc.date(byAdding: .day, value: days, to: start)!
        return Meeting(id: id, title: id, start: start, end: end, isAllDay: true, color: .init(red: 0, green: 0, blue: 0), joinURL: nil)
    }

    @Test func theAgendaGroupsTheComingDays() {
        let meetings = [
            meeting("review", startsIn: 51 * hour),  // Monday morning
            meeting("dentist", startsIn: 26 * hour),  // tomorrow
            meeting("gym", startsIn: 2 * hour),  // highlighted, so left out
            meeting("done", startsIn: -2 * hour),  // already over
            allDay("trip", dayOffset: -1, days: 3),  // began yesterday: listed under today
            allDay("holiday", dayOffset: 0),
        ]
        let days = MeetingSchedule.agenda(meetings, now: t0, excluding: meetings[2].id, calendar: utc)
        let today = utc.startOfDay(for: t0)
        #expect(days.map(\.date) == [0, 1, 2].map { utc.date(byAdding: .day, value: $0, to: today)! })
        #expect(days.map { $0.events.map(\.title) } == [["holiday", "trip"], ["dentist"], ["review"]])
    }

    @Test func allDayEventsComeFirstThenByTime() {
        let meetings = [meeting("late", startsIn: 3 * hour), meeting("early", startsIn: 1 * hour), allDay("birthday", dayOffset: 0)]
        let today = MeetingSchedule.agenda(meetings, now: t0, calendar: utc).first
        #expect(today?.events.map(\.title) == ["birthday", "early", "late"])
    }

    @Test func daysAreNamedSimply() {
        let usEnglish = Locale(identifier: "en_US")
        #expect(MeetingSchedule.dayTitle(t0 + 5 * hour, now: t0, calendar: utc) == "Today")
        #expect(MeetingSchedule.dayTitle(t0 + 24 * hour, now: t0, calendar: utc) == "Tomorrow")
        #expect(MeetingSchedule.dayTitle(t0 + 48 * hour, now: t0, calendar: utc, locale: usEnglish) == "Monday, May 11")
    }

    @Test func aLaterDayShowsTheDayInsteadOfHours() {
        #expect(MeetingSchedule.relativeText(for: meeting("dentist", startsIn: 26 * hour), now: t0, calendar: utc) == "Tomorrow")
        #expect(MeetingSchedule.relativeText(for: meeting("gym", startsIn: 2 * hour), now: t0, calendar: utc) == "in 2h")
    }

    // MARK: - Join links

    @Test func joinLinksAreFoundForEachService() {
        let cases: [(String, MeetingLinkFinder.Service)] = [
            ("Join: https://acme.zoom.us/j/123456789?pwd=abc", .zoom),
            ("https://meet.google.com/abc-defg-hij", .googleMeet),
            ("Click here to join <https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y>", .teams),
            ("https://acme.webex.com/meet/jane", .webex),
            ("FaceTime: https://facetime.apple.com/join#v=1&p=abc", .faceTime),
        ]
        for (text, service) in cases {
            let url = MeetingLinkFinder.find(in: [text])
            #expect(url != nil, "no link in: \(text)")
            #expect(url.flatMap(MeetingLinkFinder.Service.matching) == service)
        }
    }

    @Test func ordinaryLinksAreNotJoinLinks() {
        #expect(MeetingLinkFinder.find(in: ["Agenda: https://docs.google.com/document/d/1", "Room 4B", nil]) == nil)
        #expect(MeetingLinkFinder.find(in: ["https://zoom.us/pricing"]) == nil)
    }

    @Test func theEventURLFieldWinsOverTheNotes() {
        let url = MeetingLinkFinder.find(in: ["https://meet.google.com/aaa-bbbb-ccc", nil, "Backup: https://acme.zoom.us/j/1"])
        #expect(url?.host == "meet.google.com")
    }
}
