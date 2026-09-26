import Foundation
import Testing
@testable import EasyNotch

struct BatteryTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A power-source report like macOS gives, with the owner's Mac's values by default:
    /// 80%, plugged in, not charging (macOS holding the charge).
    func report(
        percent: Int = 80, plugged: Bool = true, charging: Bool = false, charged: Bool = false,
        toEmpty: Int = -1, toFull: Int = -1
    ) -> [String: Any] {
        [
            "Type": "InternalBattery",
            "Current Capacity": percent,
            "Max Capacity": 100,
            "Power Source State": plugged ? "AC Power" : "Battery Power",
            "Is Charging": charging,
            "Is Charged": charged,
            "Time to Empty": toEmpty,
            "Time to Full Charge": toFull,
        ]
    }

    func snapshot(_ report: [String: Any]) -> BatterySnapshot {
        BatterySnapshot(powerSource: report)!
    }

    // MARK: - Reading the report

    @Test func theOwnersMacIsHoldingItsChargeAt80() {
        let battery = snapshot(report())
        #expect(battery.percent == 80)
        #expect(battery.isPluggedIn)
        #expect(battery.isHoldingCharge)
        #expect(battery.statusText == "Plugged in · holding at 80% to protect the battery")
    }

    @Test func statusTextCoversEveryState() {
        #expect(snapshot(report(charging: true, toFull: 72)).statusText == "Charging · full in 1 h 12 min")
        #expect(snapshot(report(charging: true)).statusText == "Charging")  // still estimating
        #expect(snapshot(report(percent: 100, charged: true)).statusText == "Fully charged")
        #expect(snapshot(report(percent: 64, plugged: false, toEmpty: 340)).statusText == "On battery · 5 h 40 min left")
        #expect(snapshot(report(percent: 64, plugged: false)).statusText == "On battery")
    }

    @Test func somethingOtherThanTheMacsBatteryIsIgnored() {
        var ups = report()
        ups["Type"] = "UPS"
        #expect(BatterySnapshot(powerSource: ups) == nil)
    }

    @Test func healthIsCappedAt100() {
        // The owner's new battery holds slightly more than its design capacity.
        #expect(BatterySnapshot.health(designCapacity: 6249, fullChargeCapacity: 6523) == 100)
        #expect(BatterySnapshot.health(designCapacity: 6000, fullChargeCapacity: 5100) == 85)
        #expect(BatterySnapshot.health(designCapacity: 0, fullChargeCapacity: 5100) == nil)
    }

    @Test func durationsReadNaturally() {
        #expect(BatterySnapshot.duration(45) == "45 min")
        #expect(BatterySnapshot.duration(60) == "1 h")
        #expect(BatterySnapshot.duration(72) == "1 h 12 min")
    }

    // MARK: - Flash and low-battery warning

    @Test func pluggingInFlashesForAFewSeconds() {
        var alerts = BatteryAlerts()
        alerts.update(snapshot(report(plugged: false)), now: t0, lowThreshold: 10)
        #expect(!alerts.isFlashing(at: t0))

        alerts.update(snapshot(report(plugged: true, charging: true)), now: t0 + 1, lowThreshold: 10)
        #expect(alerts.isFlashing(at: t0 + 2))
        #expect(!alerts.isFlashing(at: t0 + 1 + BatteryAlerts.flashDuration))
    }

    @Test func alreadyPluggedInAtLaunchDoesNotFlash() {
        var alerts = BatteryAlerts()
        alerts.update(snapshot(report()), now: t0, lowThreshold: 10)
        #expect(!alerts.isFlashing(at: t0))
    }

    @Test func lowBatteryWarningDoesNotFlickerAtTheThreshold() {
        var alerts = BatteryAlerts()
        alerts.update(snapshot(report(percent: 10, plugged: false)), now: t0, lowThreshold: 10)
        #expect(alerts.isLow)

        alerts.update(snapshot(report(percent: 11, plugged: false)), now: t0, lowThreshold: 10)
        #expect(alerts.isLow)  // within 2% of the threshold: still low

        alerts.update(snapshot(report(percent: 13, plugged: false)), now: t0, lowThreshold: 10)
        #expect(!alerts.isLow)

        alerts.update(snapshot(report(percent: 5, plugged: true, charging: true)), now: t0, lowThreshold: 10)
        #expect(!alerts.isLow)  // plugged in: no warning
    }
}
