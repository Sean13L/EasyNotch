import AppKit
import SwiftUI

/// Pomodoro timer lengths, flow, and alerts.
struct PomodoroPane: View {
    @Bindable var settings: AppSettings

    /// The sounds every Mac has in /System/Library/Sounds.
    private static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    var body: some View {
        Form {
            Section {
                SettingSlider(
                    title: "Focus",
                    value: $settings.focusMinutes, setting: .focusMinutes, step: 1, unit: .minutes
                )
                SettingSlider(
                    title: "Short break",
                    value: $settings.shortBreakMinutes, setting: .shortBreakMinutes, step: 1, unit: .minutes
                )
                SettingSlider(
                    title: "Long break",
                    value: $settings.longBreakMinutes, setting: .longBreakMinutes, step: 1, unit: .minutes
                )
                SettingSlider(
                    title: "Long break after",
                    value: $settings.sessionsBeforeLongBreak, setting: .sessionsBeforeLongBreak,
                    step: 1, unit: .count("focus sessions")
                )
            } header: {
                Text("Lengths")
            } footer: {
                Text("Changes apply from the next session; a running timer keeps its time.")
            }

            Section("Flow") {
                Toggle("Start breaks automatically", isOn: $settings.autoStartBreaks)
                Toggle("Start focus sessions automatically", isOn: $settings.autoStartFocus)
                Toggle("Show the timer beside the notch", isOn: $settings.pomodoroInNotch)
            }

            Section("When a session ends") {
                Toggle("Show a notification", isOn: $settings.pomodoroNotifications)
                Toggle("Play a sound", isOn: $settings.pomodoroSoundEnabled)
                Picker("Sound", selection: $settings.pomodoroSound) {
                    ForEach(Self.systemSounds, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!settings.pomodoroSoundEnabled)
                .onChange(of: settings.pomodoroSound) { _, name in
                    NSSound(named: NSSound.Name(name))?.play()  // preview the choice
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pomodoro")
    }
}
