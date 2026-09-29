import Foundation
import IOKit
import IOKit.ps
import Observation

/// The Mac's battery, kept up to date by macOS's power-source notifications (no polling, no
/// permission). `snapshot` is nil on a Mac without a battery.
@Observable
final class BatteryService {
    private(set) var snapshot: BatterySnapshot?
    /// True for a few seconds after a charger is connected (if that option is on).
    private(set) var isFlashing = false
    /// True while the battery is at or below the warning threshold (if that option is on).
    private(set) var isLow = false
    /// The low-battery warning beside the notch; hidden once the user has opened the notch.
    private(set) var showsLowWarning = false

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var alerts = BatteryAlerts()
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var flashTask: Task<Void, Never>?
    @ObservationIgnored private var lowPowerObserver: NSObjectProtocol?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Starts listening. Called once at launch (never in tests).
    func activate() {
        refresh()
        // macOS calls this whenever anything about the battery or charger changes. The callback
        // is plain C, so it gets a pointer to `self` instead of capturing it.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        watchSettings()
    }

    func refresh() {
        guard var fresh = Self.readInternalBattery() else {
            snapshot = nil
            return
        }
        fresh.adapterWatts = fresh.isPluggedIn ? Self.readAdapterWatts() : nil
        let (health, cycles) = Self.readHealth()
        fresh.healthPercent = health
        fresh.cycleCount = cycles
        fresh.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        if fresh != snapshot {
            Log.battery.notice("Battery \(fresh.percent)%, \(fresh.isPluggedIn ? "plugged in" : "on battery", privacy: .public)\(fresh.isCharging ? ", charging" : "", privacy: .public)")
        }
        snapshot = fresh

        let now = Date.now
        alerts.update(fresh, now: now, lowThreshold: Int(settings.batteryLowThreshold))
        isLow = settings.batteryLowWarning && alerts.isLow
        showsLowWarning = settings.batteryLowWarning && alerts.showsLowWarning
        updateFlash(now: now)
    }

    // MARK: - Private

    /// The user opened the notch and has seen the low-battery warning.
    func acknowledgeAlerts() {
        alerts.acknowledgeLow()
        showsLowWarning = settings.batteryLowWarning && alerts.showsLowWarning
    }

    /// Applies the warning and flash settings right away, not at the next battery change.
    private func watchSettings() {
        withObservationTracking {
            _ = settings.batteryLowWarning
            _ = settings.batteryLowThreshold
            _ = settings.batteryChargingFlash
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.watchSettings()
            }
        }
    }

    private func updateFlash(now: Date) {
        let flashing = settings.batteryChargingFlash && alerts.isFlashing(at: now)
        guard flashing != isFlashing else { return }
        isFlashing = flashing
        flashTask?.cancel()
        guard flashing, let endsAt = alerts.flashEndsAt else { return }
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(endsAt.timeIntervalSinceNow), tolerance: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.isFlashing = false
        }
    }

    private static func readInternalBattery() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
               let snapshot = BatterySnapshot(powerSource: description) {
                return snapshot
            }
        }
        return nil
    }

    private static func readAdapterWatts() -> Int? {
        let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        return details?["Watts"] as? Int
    }

    /// Health and cycle count, from the battery's own controller (no permission needed).
    private static func readHealth() -> (health: Int?, cycles: Int?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        let cycles = property("CycleCount") as? Int
        let data = property("BatteryData") as? [String: Any]
        let design = data?["DesignCapacity"] as? Int ?? property("DesignCapacity") as? Int
        let full = data?["NominalChargeCapacity"] as? Int ?? property("NominalChargeCapacity") as? Int
        guard let design, let full else { return (nil, cycles) }
        return (BatterySnapshot.health(designCapacity: design, fullChargeCapacity: full), cycles)
    }
}
