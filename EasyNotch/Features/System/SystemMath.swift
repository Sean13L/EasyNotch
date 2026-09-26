import Foundation

/// The arithmetic behind the System tab. Pure, tested.
nonisolated enum SystemMath {
    /// CPU time counters ("ticks") as macOS reports them. They only ever go up (and wrap around
    /// at 2³²), so usage is worked out from the change between two readings.
    struct CPUTicks: Equatable, Sendable {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    /// How busy the CPU was between two readings, from 0 to 1.
    static func cpuUsage(from old: CPUTicks, to new: CPUTicks) -> Double {
        // Wrapping subtraction (&-) gives the right difference even after a counter wraps.
        let busy = Double(new.user &- old.user) + Double(new.system &- old.system) + Double(new.nice &- old.nice)
        let total = busy + Double(new.idle &- old.idle)
        return total > 0 ? min(1, max(0, busy / total)) : 0
    }

    /// Bytes received and sent by one network interface. macOS keeps these in 32 bits, so they
    /// wrap back to zero every 4 GB.
    struct InterfaceCounters: Equatable, Sendable {
        var received: UInt32
        var sent: UInt32
    }

    /// Download and upload speeds in bytes per second, summed over interfaces present in both
    /// readings.
    static func networkRate(
        from old: [String: InterfaceCounters], to new: [String: InterfaceCounters], seconds: Double
    ) -> (down: Double, up: Double) {
        guard seconds > 0 else { return (0, 0) }
        var down = 0.0
        var up = 0.0
        for (name, now) in new {
            guard let before = old[name] else { continue }
            down += Double(now.received &- before.received)
            up += Double(now.sent &- before.sent)
        }
        return (down / seconds, up / seconds)
    }

    /// Only real network hardware (Wi-Fi, Ethernet, cellular), so VPN traffic isn't counted twice.
    static func isPhysicalInterface(_ name: String) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("pdp_ip")
    }

    /// "0 KB/s", "850 KB/s", "1.2 MB/s", "35 MB/s", "1.1 GB/s".
    static func rateText(_ bytesPerSecond: Double) -> String {
        sizeText(bytesPerSecond) + "/s"
    }

    /// "850 KB", "1.2 MB", "35 MB", "12.4 GB", using 1000 as the step like Finder does.
    static func sizeText(_ bytes: Double) -> String {
        let units = ["KB", "MB", "GB", "TB"]
        var value = max(0, bytes) / 1000
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        let digits = unit >= 1 && value < 10 ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits))) + " " + units[unit]
    }

    /// Decides when network traffic counts as "a big transfer": above the threshold for
    /// `requiredSamples` readings in a row, and over once it drops below for as many.
    struct TransferDetector: Equatable, Sendable {
        static let requiredSamples = 2

        private(set) var isTransferring = false
        private var streak = 0

        mutating func update(bytesPerSecond: Double, threshold: Double) {
            let above = bytesPerSecond >= threshold
            if above == isTransferring {
                streak = 0
                return
            }
            streak += 1
            if streak >= Self.requiredSamples {
                isTransferring = above
                streak = 0
            }
        }
    }
}
