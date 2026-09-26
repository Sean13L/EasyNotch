import Testing
@testable import EasyNotch

struct SystemMathTests {
    typealias Ticks = SystemMath.CPUTicks
    typealias Counters = SystemMath.InterfaceCounters

    @Test func cpuUsageComesFromTheChangeInTicks() {
        let before = Ticks(user: 100, system: 50, idle: 850, nice: 0)
        let after = Ticks(user: 160, system: 70, idle: 870, nice: 0)
        // 80 busy ticks out of 100 → 80%.
        #expect(SystemMath.cpuUsage(from: before, to: after) == 0.8)
        #expect(SystemMath.cpuUsage(from: before, to: before) == 0)
    }

    @Test func cpuUsageSurvivesACounterWrapping() {
        let before = Ticks(user: UInt32.max - 9, system: 0, idle: 0, nice: 0)
        let after = Ticks(user: 10, system: 0, idle: 20, nice: 0)
        // 20 busy ticks (across the wrap) + 20 idle → 50%.
        #expect(SystemMath.cpuUsage(from: before, to: after) == 0.5)
    }

    @Test func networkRateSumsInterfacesAndSurvivesWrapping() {
        let before = ["en0": Counters(received: 1_000, sent: 500), "en1": Counters(received: UInt32.max - 999, sent: 0)]
        let after = ["en0": Counters(received: 3_000, sent: 1_500), "en1": Counters(received: 1_000, sent: 0)]
        let rate = SystemMath.networkRate(from: before, to: after, seconds: 2)
        // en0: 2 000 down, 1 000 up; en1: 2 000 down across the wrap. Over 2 seconds.
        #expect(rate.down == 2_000)
        #expect(rate.up == 500)
    }

    @Test func aNewInterfaceIsIgnoredUntilItHasTwoReadings() {
        let rate = SystemMath.networkRate(from: [:], to: ["en0": Counters(received: 5_000_000, sent: 0)], seconds: 1)
        #expect(rate.down == 0)
    }

    @Test func onlyRealNetworkHardwareCounts() {
        #expect(SystemMath.isPhysicalInterface("en0"))
        #expect(SystemMath.isPhysicalInterface("pdp_ip0"))
        #expect(!SystemMath.isPhysicalInterface("lo0"))
        #expect(!SystemMath.isPhysicalInterface("utun3"))  // VPN
    }

    @Test func ratesAndSizesReadLikeFinder() {
        #expect(SystemMath.rateText(0) == "0 KB/s")
        #expect(SystemMath.rateText(850_000) == "850 KB/s")
        #expect(SystemMath.rateText(1_234_000) == "1.2 MB/s")
        #expect(SystemMath.rateText(35_000_000) == "35 MB/s")
        #expect(SystemMath.sizeText(12_400_000_000) == "12 GB")
        #expect(SystemMath.sizeText(1_100_000_000) == "1.1 GB")
    }

    @Test func aTransferHasToLastBeforeItShows() {
        var detector = SystemMath.TransferDetector()
        let threshold = 5_000_000.0
        detector.update(bytesPerSecond: 20_000_000, threshold: threshold)
        #expect(!detector.isTransferring)  // one fast reading isn't enough
        detector.update(bytesPerSecond: 20_000_000, threshold: threshold)
        #expect(detector.isTransferring)

        detector.update(bytesPerSecond: 0, threshold: threshold)
        #expect(detector.isTransferring)  // one quiet reading doesn't end it
        detector.update(bytesPerSecond: 0, threshold: threshold)
        #expect(!detector.isTransferring)
    }
}
