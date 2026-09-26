import SwiftUI

/// Upcoming meetings: when they show beside the notch, and which calendars count.
struct CalendarPane: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService

    var body: some View {
        Form {
            Section {
                Toggle("Show upcoming meetings beside the notch", isOn: $settings.calendarInNotch)
                Picker("Start showing them", selection: $settings.calendarLeadMinutes) {
                    ForEach([1.0, 2, 5, 10, 15], id: \.self) { minutes in
                        Text("\(Int(minutes)) minute\(minutes == 1 ? "" : "s") before").tag(minutes)
                    }
                }
                .disabled(!settings.calendarInNotch)
                Toggle("List all-day events", isOn: $settings.calendarShowAllDay)
            } footer: {
                Text("A meeting stays beside the notch until 5 minutes after it starts. Meetings you've declined are never shown.")
            }

            Section {
                switch calendar.access {
                case .granted:
                    if calendar.calendars.isEmpty {
                        Text("No calendars found.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(calendar.calendars) { info in
                        Toggle(isOn: includedBinding(info.id)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(info.color.swiftUIColor)
                                    .frame(width: 9, height: 9)
                                Text(info.title)
                                Text(info.account)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                case .notDetermined:
                    LabeledContent("EasyNotch hasn't been allowed to read your calendars yet.") {
                        Button("Allow…") { Task { await calendar.requestAccess() } }
                    }
                case .denied:
                    LabeledContent("Calendar access is turned off.") {
                        Button("Open System Settings") { NSWorkspace.shared.open(CalendarService.privacySettingsURL) }
                    }
                }
            } header: {
                Text("Calendars")
            } footer: {
                Text("Events are read on this Mac only and never sent anywhere.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Calendar")
        .onAppear { calendar.reload() }
    }

    private func includedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !settings.calendarHiddenIDs.contains(id) },
            set: { isIncluded in
                var hidden = settings.calendarHiddenIDs.filter { $0 != id }
                if !isIncluded { hidden.append(id) }
                settings.calendarHiddenIDs = hidden
            }
        )
    }
}
