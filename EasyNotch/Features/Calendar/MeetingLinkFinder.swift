import Foundation

/// Finds a video-call link in a calendar event's URL, location, or notes. Pure, tested.
nonisolated enum MeetingLinkFinder {
    /// The services we recognize, by the web address their links use.
    enum Service: String, Sendable {
        case zoom = "Zoom"
        case googleMeet = "Google Meet"
        case teams = "Teams"
        case webex = "Webex"
        case faceTime = "FaceTime"

        static func matching(_ url: URL) -> Service? {
            guard let host = url.host?.lowercased() else { return nil }
            let path = url.path.lowercased()
            if host.hasSuffix("zoom.us"), path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/w/") { return .zoom }
            if host == "meet.google.com", path.count > 1 { return .googleMeet }
            if host == "teams.microsoft.com", path.hasPrefix("/l/meetup-join") { return .teams }
            if host == "teams.live.com", path.hasPrefix("/meet") { return .teams }
            if host.hasSuffix("webex.com"), path.count > 1 { return .webex }
            if host == "facetime.apple.com", path.hasPrefix("/join") { return .faceTime }
            return nil
        }
    }

    /// The first video-call link in `texts`, checked in order (e.g. URL field, location, notes).
    static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, url.scheme?.hasPrefix("http") == true, Service.matching(url) != nil {
                    return url
                }
            }
        }
        return nil
    }
}
