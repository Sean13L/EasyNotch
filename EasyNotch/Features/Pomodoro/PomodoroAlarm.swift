import AppKit

/// Plays the chosen sound several times in a row, so a phase end sounds like an alarm instead
/// of a single blip. While it rings, other apps' sound is muted so the alarm stands out.
/// Call `stop()` when the user acts on the timer, so the alarm doesn't keep going.
@MainActor
final class PomodoroAlarm {
    private static let repeatCount = 16
    private static let gap: Duration = .milliseconds(500)

    private var task: Task<Void, Never>?
    /// The mute in place while the alarm rings. Stored as `Any` because the muter needs macOS 14.2;
    /// see `SpatialAudioController` for the same pattern.
    private var muter: Any?

    func ring(soundName: String) {
        stop()
        muteOtherApps()
        task = Task {
            for _ in 0..<Self.repeatCount {
                guard !Task.isCancelled else { break }
                NSSound(named: NSSound.Name(soundName))?.play()
                try? await Task.sleep(for: Self.gap)
            }
            unmuteOtherApps()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        unmuteOtherApps()
    }

    private func muteOtherApps() {
        guard #available(macOS 14.2, *) else { return }
        let muter = SystemAudioMuter()
        do {
            try muter.mute()
            self.muter = muter
        } catch {
            // Usually the audio-recording permission isn't granted yet. The alarm still plays.
            Log.pomodoro.error("Couldn't mute other apps: \(String(describing: error), privacy: .public)")
        }
    }

    private func unmuteOtherApps() {
        guard #available(macOS 14.2, *) else { return }
        (muter as? SystemAudioMuter)?.unmute()
        muter = nil
    }
}
