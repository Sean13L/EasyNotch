import AppKit
import Testing
@testable import EasyNotch

/// Checks that cover downloads are retried when the network fails, and only then.
struct ArtworkDownloaderTests {
    let url = URL(string: "https://i.scdn.co/image/cover")!

    /// A tiny PNG, standing in for a cover.
    let png: Data = {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }()

    /// A downloader with no waiting between retries, whose network fails `failures` times
    /// and then returns `data`. `attempts` counts the downloads it tried.
    func downloader(failures: Int, then data: Data, attempts: Counter) -> ArtworkDownloader {
        var downloader = ArtworkDownloader()
        downloader.retryDelays = [.zero, .zero, .zero]
        downloader.fetch = { request in
            attempts.value += 1
            attempts.timeout = request.timeoutInterval
            if attempts.value <= failures { throw URLError(.timedOut) }
            return data
        }
        return downloader
    }

    final class Counter {
        var value = 0
        var timeout: TimeInterval = 0
    }

    @Test func aWorkingDownloadGivesTheImageWithAShortTimeLimit() async {
        let attempts = Counter()
        let outcome = await downloader(failures: 0, then: png, attempts: attempts).image(from: url) { true }
        guard case .image = outcome else { Issue.record("Expected an image, got \(outcome)"); return }
        #expect(attempts.value == 1)
        #expect(attempts.timeout == 10)
    }

    @Test func aFailedDownloadIsTriedAgain() async {
        let attempts = Counter()
        let outcome = await downloader(failures: 2, then: png, attempts: attempts).image(from: url) { true }
        guard case .image = outcome else { Issue.record("Expected an image, got \(outcome)"); return }
        #expect(attempts.value == 3)
    }

    @Test func itGivesUpAfterTheLastRetry() async {
        let attempts = Counter()
        let outcome = await downloader(failures: .max, then: png, attempts: attempts).image(from: url) { true }
        guard case .failed = outcome else { Issue.record("Expected a failure, got \(outcome)"); return }
        #expect(attempts.value == 4)
    }

    @Test func itStopsRetryingWhenAskedTo() async {
        let attempts = Counter()
        let outcome = await downloader(failures: .max, then: png, attempts: attempts).image(from: url) { false }
        guard case .failed = outcome else { Issue.record("Expected a failure, got \(outcome)"); return }
        #expect(attempts.value == 1)
    }

    @Test func anAnswerThatIsNotAnImageIsNotRetried() async {
        let attempts = Counter()
        let outcome = await downloader(failures: 0, then: Data("Not found".utf8), attempts: attempts).image(from: url) { true }
        guard case .notAnImage = outcome else { Issue.record("Expected not-an-image, got \(outcome)"); return }
        #expect(attempts.value == 1)
    }
}
