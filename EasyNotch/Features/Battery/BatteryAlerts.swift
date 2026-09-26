import Foundation

/// Decides when the battery shows beside the notch. Pure, tested.
/// - A short **charging flash** right after a charger is connected, like an iPhone.
/// - A **low-battery warning** at or below the threshold while on battery. It only clears 2%
///   above the threshold, so it doesn't flicker on and off at the boundary.
nonisolated struct BatteryAlerts: Equatable, Sendable {
    static let flashDuration: TimeInterval = 4
    static let lowBatteryHysteresis = 2

    private(set) var flashEndsAt: Date?
    private(set) var isLow = false
    private var wasPluggedIn: Bool?

    mutating func update(_ snapshot: BatterySnapshot, now: Date, lowThreshold: Int) {
        if wasPluggedIn == false, snapshot.isPluggedIn {
            flashEndsAt = now + Self.flashDuration
        } else if !snapshot.isPluggedIn {
            flashEndsAt = nil
        }
        wasPluggedIn = snapshot.isPluggedIn

        if snapshot.isPluggedIn {
            isLow = false
        } else if snapshot.percent <= lowThreshold {
            isLow = true
        } else if snapshot.percent > lowThreshold + Self.lowBatteryHysteresis {
            isLow = false
        }
    }

    func isFlashing(at now: Date) -> Bool {
        flashEndsAt.map { now < $0 } ?? false
    }
}
