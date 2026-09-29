import Foundation

/// Decides which meeting to alert about beside the notch. Pure, tested.
///
/// An alert starts when a meeting enters its window (the lead time before it until 5 minutes
/// after it starts) and then stays up until the user opens the notch (`acknowledge`) or the
/// meeting ends, so a reminder is never missed just because nobody was looking.
nonisolated struct MeetingAlerts: Equatable, Sendable {
    /// Meetings whose alert has started.
    private(set) var started: Set<String> = []
    /// Meetings whose alert the user has seen.
    private(set) var acknowledged: Set<String> = []

    /// The meeting to show beside the notch now, if any.
    mutating func update(_ meetings: [Meeting], now: Date, lead: TimeInterval) -> Meeting? {
        let upcoming = MeetingSchedule.upcoming(meetings, now: now)
        // Forget meetings that have ended or been removed.
        let current = Set(upcoming.map(\.id))
        started.formIntersection(current)
        acknowledged.formIntersection(current)

        for meeting in upcoming
        where meeting.start - lead <= now && now < meeting.start + MeetingSchedule.showsAfterStart {
            started.insert(meeting.id)
        }
        return upcoming.first { started.contains($0.id) && !acknowledged.contains($0.id) }
    }

    /// The user opened the notch, so every alert showing so far has been seen.
    mutating func acknowledge() {
        acknowledged.formUnion(started)
    }
}
