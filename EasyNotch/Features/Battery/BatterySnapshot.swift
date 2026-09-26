import Foundation

/// The battery's state at one moment, read from macOS's power-source report. Pure, tested.
nonisolated struct BatterySnapshot: Equatable, Sendable {
    var percent: Int
    var isPluggedIn: Bool
    var isCharging: Bool
    var isCharged: Bool
    /// Minutes left on battery; nil while macOS is still estimating.
    var minutesToEmpty: Int?
    /// Minutes until full; nil while macOS is still estimating.
    var minutesToFull: Int?
    var adapterWatts: Int?
    /// Full capacity now vs. when new, capped at 100%.
    var healthPercent: Int?
    var cycleCount: Int?
    var isLowPowerMode = false

    /// Plugged in, but macOS is holding the charge (optimized charging or a charge limit) to
    /// protect the battery.
    var isHoldingCharge: Bool {
        isPluggedIn && !isCharging && !isCharged && percent < 100
    }

    /// Builds a snapshot from one entry of `IOPSCopyPowerSourcesInfo`. Returns nil for anything
    /// that isn't the Mac's own battery (e.g. a UPS).
    init?(powerSource description: [String: Any]) {
        guard description["Type"] as? String == "InternalBattery",
              let current = description["Current Capacity"] as? Int,
              let maximum = description["Max Capacity"] as? Int, maximum > 0
        else { return nil }
        percent = Int((Double(current) / Double(maximum) * 100).rounded())
        isPluggedIn = description["Power Source State"] as? String == "AC Power"
        isCharging = description["Is Charging"] as? Bool ?? false
        isCharged = description["Is Charged"] as? Bool ?? false
        // macOS reports -1 while it's still working out an estimate.
        minutesToEmpty = (description["Time to Empty"] as? Int).flatMap { $0 >= 0 ? $0 : nil }
        minutesToFull = (description["Time to Full Charge"] as? Int).flatMap { $0 >= 0 ? $0 : nil }
    }

    /// "100%" for a battery that holds at least what it did when new.
    static func health(designCapacity: Int, fullChargeCapacity: Int) -> Int? {
        guard designCapacity > 0, fullChargeCapacity > 0 else { return nil }
        return min(100, Int((Double(fullChargeCapacity) / Double(designCapacity) * 100).rounded()))
    }

    /// A short sentence describing what the battery is doing.
    var statusText: String {
        if isPluggedIn {
            if isCharged || percent >= 100 { return "Fully charged" }
            if isCharging {
                return minutesToFull.map { "Charging · full in \(Self.duration($0))" } ?? "Charging"
            }
            return "Plugged in · holding at \(percent)% to protect the battery"
        }
        return minutesToEmpty.map { "On battery · \(Self.duration($0)) left" } ?? "On battery"
    }

    /// "45 min", "1 h 12 min", "3 h".
    static func duration(_ minutes: Int) -> String {
        let (hours, rest) = (minutes / 60, minutes % 60)
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// The SF Symbol matching the charge level, with a bolt while charging.
    var symbolName: String {
        if isPluggedIn && (isCharging || isCharged) { return "battery.100percent.bolt" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
