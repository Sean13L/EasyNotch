import Darwin
import Foundation
import Observation

/// Measures CPU, memory, network, and disk, only when something needs it:
/// - once a second while a System tab is on screen, or
/// - network only, every 2 s, while "Show big transfers beside the notch" is on.
///
/// Otherwise nothing runs at all.
@Observable
final class SystemMonitor {
    enum MemoryPressure: String {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
    }

    static let historyLength = 60
    /// Free space barely changes, and asking for it costs ~15 ms (macOS totals up purgeable files).
    static let diskRefreshInterval: TimeInterval = 30

    /// 0…1.
    private(set) var cpu = 0.0
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryUsed: UInt64 = 0
    private(set) var memoryTotal = ProcessInfo.processInfo.physicalMemory
    private(set) var memoryPressure = MemoryPressure.normal
    /// Bytes per second.
    private(set) var download = 0.0
    private(set) var upload = 0.0
    private(set) var downloadHistory: [Double] = []
    private(set) var diskFree: Int64 = 0
    private(set) var thermalState = ProcessInfo.ThermalState.nominal
    /// A big transfer is going on (see `SystemMath.TransferDetector`).
    private(set) var isTransferring = false

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private var samplingTask: Task<Void, Never>?
    @ObservationIgnored private var lastTicks: SystemMath.CPUTicks?
    @ObservationIgnored private var lastCounters: [String: SystemMath.InterfaceCounters] = [:]
    @ObservationIgnored private var lastSampleAt: Date?
    @ObservationIgnored private var diskReadAt: Date?
    @ObservationIgnored private var transfers = SystemMath.TransferDetector()
    #if DEBUG
    /// Development only: log every sample (see `-SampleSystemOnLaunch`).
    @ObservationIgnored var logsSamples = false
    #endif

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Called once at launch (never in tests).
    func activate() {
        watchSettings()
    }

    /// A System tab appeared; measure everything once a second until `endWatching`.
    func beginWatching() {
        if watchers == 0 {
            // Ticks from before the tab closed would average the CPU over the whole gap.
            lastTicks = nil
            diskReadAt = nil
        }
        watchers += 1
        updateSampling()
    }

    func endWatching() {
        watchers = max(0, watchers - 1)
        updateSampling()
    }

    // MARK: - Sampling

    private var interval: Duration? {
        if watchers > 0 { return .seconds(1) }
        if settings.systemTransferInNotch { return .seconds(2) }
        return nil
    }

    private func updateSampling() {
        let wasSampling = samplingTask != nil
        samplingTask?.cancel()
        samplingTask = nil
        guard let interval else {
            isTransferring = false
            return
        }
        if !wasSampling {
            // Same for network counters from before a pause.
            lastCounters = [:]
            lastSampleAt = nil
        }
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: interval, tolerance: .milliseconds(200))
            }
        }
    }

    private func sample() {
        let now = Date.now
        let seconds = lastSampleAt.map { now.timeIntervalSince($0) } ?? 0
        lastSampleAt = now

        // Network: always (it feeds both the tab and the transfer indicator).
        let counters = Self.readInterfaceCounters()
        let rate = SystemMath.networkRate(from: lastCounters, to: counters, seconds: seconds)
        lastCounters = counters
        download = rate.down
        upload = rate.up
        Self.append(rate.down, to: &downloadHistory)
        transfers.update(
            bytesPerSecond: max(rate.down, rate.up),
            threshold: settings.systemTransferThreshold * 1_000_000
        )
        isTransferring = settings.systemTransferInNotch && transfers.isTransferring

        // Everything else only while the tab is on screen.
        guard watchers > 0 else { return }
        if let ticks = Self.readCPUTicks() {
            if let lastTicks {
                cpu = SystemMath.cpuUsage(from: lastTicks, to: ticks)
                Self.append(cpu, to: &cpuHistory)
            }
            lastTicks = ticks
        }
        memoryUsed = Self.readMemoryUsed() ?? memoryUsed
        memoryPressure = Self.readMemoryPressure()
        if diskReadAt.map({ now.timeIntervalSince($0) >= Self.diskRefreshInterval }) ?? true {
            diskFree = Self.readDiskFree() ?? diskFree
            diskReadAt = now
        }
        thermalState = ProcessInfo.processInfo.thermalState

        #if DEBUG
        if logsSamples {
            Log.system.notice("CPU \(Int(self.cpu * 100))% · memory \(SystemMath.sizeText(Double(self.memoryUsed)), privacy: .public) · ↓ \(SystemMath.rateText(self.download), privacy: .public) ↑ \(SystemMath.rateText(self.upload), privacy: .public)")
        }
        #endif
    }

    private static func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyLength { history.removeFirst(history.count - historyLength) }
    }

    /// Restarts sampling when the transfer indicator is switched on or off.
    private func watchSettings() {
        withObservationTracking {
            _ = settings.systemTransferInNotch
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateSampling()
                self?.watchSettings()
            }
        }
        updateSampling()
    }

    // MARK: - Reading from macOS

    /// Each `mach_host_self()` call takes a port reference, so take one and keep it.
    private static let host = mach_host_self()

    private static func readCPUTicks() -> SystemMath.CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = info.cpu_ticks  // (user, system, idle, nice)
        return .init(user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
    }

    /// Memory in use the way Activity Monitor counts it: app memory + wired + compressed.
    private static func readMemoryUsed() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(getpagesize())
        // Unsigned subtraction would crash if the counts ever disagreed, so floor it at zero.
        let internalPages = UInt64(stats.internal_page_count)
        let purgeablePages = UInt64(stats.purgeable_count)
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let pages = appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * pageSize
    }

    private static func readMemoryPressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }

    private static func readInterfaceCounters() -> [String: SystemMath.InterfaceCounters] {
        var result: [String: SystemMath.InterfaceCounters] = [:]
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return result }
        defer { freeifaddrs(first) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            // AF_LINK entries carry the byte counters.
            guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self)
            else { continue }
            let name = String(cString: entry.ifa_name)
            guard SystemMath.isPhysicalInterface(name) else { continue }
            result[name] = .init(received: data.pointee.ifi_ibytes, sent: data.pointee.ifi_obytes)
        }
        return result
    }

    private static func readDiskFree() -> Int64? {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
