import Foundation

/// Formats time left for display.
nonisolated enum PomodoroClock {
    /// "25:00", "04:07", "00:00". Rounds up, so a fresh 25-minute timer shows 25:00 and the
    /// final second shows 00:01 rather than 00:00.
    static func string(for seconds: TimeInterval) -> String {
        // The tiny offset keeps floating-point noise (60.0000001) from rounding up a whole second.
        let total = max(0, Int((seconds - 0.001).rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
