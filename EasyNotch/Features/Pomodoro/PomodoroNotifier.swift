import Foundation
import UserNotifications

/// Schedules the "session complete" notification with macOS. The system delivers it, so it
/// arrives on time even if EasyNotch is busy or has quit.
final class PomodoroNotifier: NSObject, UNUserNotificationCenterDelegate {
    private static let requestID = "pomodoro.phaseEnd"

    private var center: UNUserNotificationCenter { .current() }

    /// Call once at launch, so banners also appear while an EasyNotch window is in front.
    func activate() {
        center.delegate = self
    }

    /// Replaces any pending notification with one for `event`, delivered at `date`.
    func schedule(_ event: PomodoroEngine.Event, at date: Date, config: PomodoroConfig) {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = Self.title(for: event)
        content.body = Self.body(for: event, config: config)
        // No sound here: the app plays the sound you picked in Settings.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow), repeats: false
        )
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger)

        Task {
            do {
                // Shows the permission prompt the first time; afterwards returns immediately.
                guard try await center.requestAuthorization(options: [.alert]) else {
                    Log.pomodoro.notice("Notifications not allowed; skipping")
                    return
                }
                try await center.add(request)
                Log.pomodoro.debug("Notification scheduled for \(date, privacy: .public)")
            } catch {
                Log.pomodoro.error("Couldn't schedule notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    // MARK: - Text

    private static func title(for event: PomodoroEngine.Event) -> String {
        event.finished == .focus ? "Focus session complete" : "Break's over"
    }

    private static func body(for event: PomodoroEngine.Event, config: PomodoroConfig) -> String {
        let minutes = Int((config.duration(of: event.next) / 60).rounded())
        switch (event.next, event.nextStartedAutomatically) {
        case (.focus, true): return "Your next focus session has started."
        case (.focus, false): return "Ready for the next focus session?"
        case (.shortBreak, true): return "Your \(minutes)-minute break has started."
        case (.shortBreak, false): return "Time for a \(minutes)-minute break."
        case (.longBreak, true): return "Your \(minutes)-minute long break has started. Nice work!"
        case (.longBreak, false): return "Time for a \(minutes)-minute long break. Nice work!"
        }
    }
}
