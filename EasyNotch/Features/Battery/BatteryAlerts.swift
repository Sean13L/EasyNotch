import Foundation

/// Decides when the battery shows beside the notch. Pure, tested.
/// - A short **charging flash** right after a charger is connected, like an iPhone.
/// - A **low-battery warning** at or below the threshold while on battery. It only clears 2%
///   above the threshold, so it doesn't flicker on and off at the boundary.
/// - The warning shows beside the notch until the user opens the notch (`acknowledgeLow`),
///   and comes back the next time the battery runs low.
nonisolated struct BatteryAlerts: Equatable, Sendable {
    static let flashDuration: TimeInterval = 4
    static let lowBatteryHysteresis = 2

    private(set) var flashEndsAt: Date?
    private(set) var isLow = false
    private(set) var lowAcknowledged = false
    /// Whether the low-battery warning should show beside the notch.
    var showsLowWarning: Bool { isLow && !lowAcknowledged }
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
        if !isLow { lowAcknowledged = false }  // warn again next time
    }

    /// The user opened the notch and has seen the warning.
    mutating func acknowledgeLow() {
        if isLow { lowAcknowledged = true }
    }

    func isFlashing(at now: Date) -> Bool {
        flashEndsAt.map { now < $0 } ?? false
    }
}
