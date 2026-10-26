import AppKit

/// Plays the chosen sound several times in a row, so a phase end sounds like an alarm instead
/// of a single blip. Call `stop()` when the user acts on the timer, so the alarm doesn't
/// keep going.
@MainActor
final class PomodoroAlarm {
    private static let repeatCount = 8
    private static let gap: Duration = .milliseconds(1500)

    private var task: Task<Void, Never>?

    func ring(soundName: String) {
        stop()
        task = Task {
            for _ in 0..<Self.repeatCount {
                guard !Task.isCancelled else { return }
                NSSound(named: NSSound.Name(soundName))?.play()
                try? await Task.sleep(for: Self.gap)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
