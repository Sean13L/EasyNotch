import AppKit

/// Downloads cover art from a link (Spotify gives one for each track).
///
/// The internet can drop out for a while, for example on weak Wi-Fi. So each attempt has a
/// short time limit, and a failed download is tried again a few times, waiting longer each
/// time. That way the cover still appears once the connection is back.
struct ArtworkDownloader {
    enum Outcome {
        case image(NSImage)
        /// The server answered, but not with an image. Trying again won't help.
        case notAnImage
        /// Every attempt failed, or `afterFailure` said to stop.
        case failed
    }

    /// The wait before each retry. The first attempt starts right away.
    var retryDelays: [Duration] = [.seconds(3), .seconds(10), .seconds(30)]
    /// How long one attempt may take. The system's default is a whole minute.
    var timeout: TimeInterval = 10
    /// Fetches the data. Tests replace it.
    var fetch: (URLRequest) async throws -> Data = { try await URLSession.shared.data(for: $0).0 }

    /// Downloads the image at `url`. `afterFailure` runs after each failed attempt; it
    /// returns false to stop trying (for example, because the track changed).
    func image(from url: URL, afterFailure: () -> Bool) async -> Outcome {
        let request = URLRequest(url: url, timeoutInterval: timeout)
        for attempt in 0...retryDelays.count {
            if attempt > 0 {
                try? await Task.sleep(for: retryDelays[attempt - 1])
            }
            do {
                let data = try await fetch(request)
                return NSImage(data: data).map(Outcome.image) ?? .notAnImage
            } catch {
                Log.music.notice("Cover download failed (attempt \(attempt + 1)): \(error.localizedDescription, privacy: .public)")
                guard afterFailure() else { return .failed }
            }
        }
        return .failed
    }
}
