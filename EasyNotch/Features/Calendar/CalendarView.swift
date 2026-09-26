import SwiftUI

/// The Calendar tab: the next meeting with a Join button, and the rest of today.
struct CalendarView: View {
    @Environment(CalendarService.self) private var calendar

    var body: some View {
        Group {
            content
        }
        // Access may have been turned on in System Settings since the tab was last shown.
        .onAppear {
            if calendar.access != .granted { calendar.reload() }
        }
    }

    @ViewBuilder private var content: some View {
        switch calendar.access {
        case .notDetermined:
            AccessMessage(
                symbol: "calendar",
                title: "See your next meeting here",
                detail: "EasyNotch reads today's events on this Mac only; nothing is sent anywhere.",
                buttonTitle: "Allow Calendar Access"
            ) {
                Task { await calendar.requestAccess() }
            }
        case .denied:
            AccessMessage(
                symbol: "calendar.badge.exclamationmark",
                title: "Calendar access is turned off",
                detail: "Turn on EasyNotch in System Settings → Privacy & Security → Calendars.",
                buttonTitle: "Open System Settings"
            ) {
                NSWorkspace.shared.open(CalendarService.privacySettingsURL)
            }
        case .granted:
            // Redraw each minute so "in 4m" stays current.
            TimelineView(.everyMinute) { context in
                MeetingsOverview(now: context.date)
            }
        }
    }
}

private struct MeetingsOverview: View {
    let now: Date

    @Environment(CalendarService.self) private var calendar

    var body: some View {
        let next = calendar.nextMeeting(now: now)
        let later = calendar.upcomingMeetings(now: now).filter { $0.id != next?.id }

        HStack(alignment: .top, spacing: 20) {
            NextMeetingCard(meeting: next, now: now)
                .frame(width: 250, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Later today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(calendar.allDayMeetings) { meeting in
                            MeetingRow(meeting: meeting, time: "All day")
                        }
                        ForEach(later) { meeting in
                            MeetingRow(meeting: meeting, time: meeting.start.formatted(date: .omitted, time: .shortened))
                        }
                        if later.isEmpty, calendar.allDayMeetings.isEmpty {
                            Text("Nothing else today")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }
}

private struct NextMeetingCard: View {
    let meeting: Meeting?
    let now: Date

    var body: some View {
        if let meeting {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(meeting.color.swiftUIColor)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(MeetingSchedule.relativeText(for: meeting, now: now).capitalizedFirst)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(meeting.color.swiftUIColor)
                    Text(meeting.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(meeting.start.formatted(date: .omitted, time: .shortened)) – \(meeting.end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let url = meeting.joinURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Join \(MeetingLinkFinder.Service.matching(url)?.rawValue ?? "")", systemImage: "video.fill")
                                .font(.callout.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("No more meetings today")
                    .font(.headline)
            }
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let time: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(meeting.color.swiftUIColor)
                .frame(width: 7, height: 7)
            Text(time)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(meeting.title)
                .lineLimit(1)
            if meeting.joinURL != nil {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

private struct AccessMessage: View {
    let symbol: String
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 40)
    }
}

extension Meeting.RGB {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}

private extension String {
    /// "in 4m" → "In 4m".
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
