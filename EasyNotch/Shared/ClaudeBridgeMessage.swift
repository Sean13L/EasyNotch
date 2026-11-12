import Foundation

// Foundation only: this file is also compiled into the command-line helper, which has no
// access to Log or any other app type. `nonisolated` because the project defaults to MainActor.

/// One usage window from Claude Code's rate limits (the 5-hour or the 7-day one).
nonisolated struct UsageWindow: Codable, Equatable, Sendable {
    var usedPercentage: Double
    var resetsAt: Date
}

nonisolated enum ClaudeBridgeError: Error, Equatable {
    case tooLong
    case invalid
}

/// A message between the app and the helper. Each one travels as a single line of JSON.
nonisolated enum ClaudeBridgeMessage: Codable, Equatable, Sendable {
    case permissionRequest(tool: String, summary: String, project: String)
    case usage(fiveHour: UsageWindow?, sevenDay: UsageWindow?)
    case decision(allow: Bool)

    static let maxLineBytes = 65_536
    static let maxSummaryBytes = 4_096

    /// JSON on one line, ending in a newline. Dates are seconds since 1970.
    func encodeLine() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        // Compact output has no raw newlines: JSON escapes them inside strings as \n.
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }

    static func decode(line: Data) throws -> ClaudeBridgeMessage {
        guard line.count <= maxLineBytes else { throw ClaudeBridgeError.tooLong }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(ClaudeBridgeMessage.self, from: line)
        } catch {
            throw ClaudeBridgeError.invalid
        }
    }

    /// `<appSupport>/EasyNotch/claude.sock`
    static func socketURL(appSupport: URL) -> URL {
        appSupport
            .appendingPathComponent("EasyNotch", isDirectory: true)
            .appendingPathComponent("claude.sock")
    }
}
