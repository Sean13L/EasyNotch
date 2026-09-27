import AppKit
import EventKit
import Observation

/// Today's meetings from the Calendar app, kept up to date without polling:
/// - it reloads when calendars change, at midnight, and after sleep
/// - between those, it sleeps until the next moment the live meeting could change
///
/// It only asks macOS for Calendars access when the user presses "Allow Calendar Access".
/// Meeting titles never go into the logs.
@Observable
final class CalendarService {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    struct CalendarInfo: Identifiable, Equatable {
        let id: String
        let title: String
        let account: String
        let color: Meeting.RGB
    }

    private(set) var access = Access.notDetermined
    /// Events from today through `calendarDaysAhead` days, from the included calendars
    /// (declined and cancelled ones left out).
    private(set) var meetings: [Meeting] = []
    /// Every event calendar, for Settings → Calendar.
    private(set) var calendars: [CalendarInfo] = []
    /// The meeting to show beside the closed notch right now (see `MeetingSchedule`).
    private(set) var liveMeeting: Meeting?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var store: EKEventStore?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var wakeTask: Task<Void, Never>?

    static let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
    /// System Settings → Internet Accounts, where Google, Outlook/Exchange, and other calendar
    /// accounts are added. EasyNotch sees their calendars once they're there, with no sign-in of
    /// its own.
    static let internetAccountsURL = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Starts watching. Called once at launch (never in tests). Doesn't ask for access.
    func activate() {
        updateAccess()
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        watchSettings()
        reload()
    }

    /// Shows macOS's Calendars permission prompt. Only called when the user asks for it.
    func requestAccess() async {
        let store = eventStore()
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            Log.calendar.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
        }
        updateAccess()
        reload()
    }

    /// The meeting to highlight in the tab: one in progress, or the next to start.
    func nextMeeting(now: Date) -> Meeting? {
        MeetingSchedule.next(meetings, now: now)
    }

    /// The coming days for the tab, leaving out `excluding` (the highlighted event).
    func agenda(now: Date, excluding excludedID: String?) -> [MeetingSchedule.Day] {
        MeetingSchedule.agenda(meetings, now: now, excluding: excludedID)
    }

    func reload() {
        updateAccess()
        guard access == .granted else {
            meetings = []
            calendars = []
            updateLiveMeeting()
            return
        }
        let store = eventStore()
        let all = store.calendars(for: .event)
        calendars = all
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title, color: Self.rgb($0.color)) }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }

        let hidden = Set(settings.calendarHiddenIDs)
        let included = all.filter { !hidden.contains($0.calendarIdentifier) }
        if included.isEmpty {
            meetings = []
        } else {
            let dayStart = Calendar.current.startOfDay(for: .now)
            let days = Int(settings.calendarDaysAhead)
            let dayEnd = Calendar.current.date(byAdding: .day, value: days, to: dayStart) ?? dayStart
            let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: included)
            meetings = store.events(matching: predicate)
                .filter { $0.status != .canceled && !Self.isDeclined($0) }
                .filter { settings.calendarShowAllDay || !$0.isAllDay }
                .map(Self.meeting)
        }
        Log.calendar.notice("Loaded \(self.meetings.count) events for the next \(Int(self.settings.calendarDaysAhead)) day(s)")
        updateLiveMeeting()
    }

    // MARK: - Private

    private func eventStore() -> EKEventStore {
        if let store { return store }
        let fresh = EKEventStore()
        store = fresh
        return fresh
    }

    private func updateAccess() {
        let current: Access = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied  // denied, restricted, or write-only
        }
        guard current != access else { return }
        // A store made before access was granted can stay empty, so start again with a new one.
        if current == .granted { store = nil }
        access = current
    }

    /// Works out the live meeting, then sleeps until it could next change.
    private func updateLiveMeeting() {
        let lead = settings.calendarLeadMinutes * 60
        let now = Date.now
        let live = settings.calendarInNotch ? MeetingSchedule.liveMeeting(meetings, now: now, lead: lead) : nil
        if live != liveMeeting { liveMeeting = live }

        wakeTask?.cancel()
        guard let next = MeetingSchedule.nextChange(meetings, now: now, lead: lead) else { return }
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.timeIntervalSinceNow + 0.5), tolerance: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.updateLiveMeeting()
        }
    }

    /// Reloads when calendar settings change.
    private func watchSettings() {
        withObservationTracking {
            _ = settings.calendarHiddenIDs
            _ = settings.calendarShowAllDay
            _ = settings.calendarInNotch
            _ = settings.calendarLeadMinutes
            _ = settings.calendarDaysAhead
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.reload()
                self?.watchSettings()
            }
        }
    }

    private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
    }

    private static func meeting(from event: EKEvent) -> Meeting {
        Meeting(
            // Repeating events share one identifier, so add the start time to tell them apart.
            id: "\(event.eventIdentifier ?? "event")-\(event.startDate.timeIntervalSinceReferenceDate)",
            title: event.title ?? "Untitled",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            color: rgb(event.calendar?.color),
            joinURL: MeetingLinkFinder.find(in: [event.url?.absoluteString, event.location, event.notes])
        )
    }

    private static func rgb(_ color: NSColor?) -> Meeting.RGB {
        guard let color = color?.usingColorSpace(.sRGB) else { return .init(red: 0.5, green: 0.5, blue: 0.5) }
        return .init(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}
