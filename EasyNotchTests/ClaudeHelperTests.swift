import Foundation
import Testing
@testable import EasyNotch

/// Runs the built helper (inside the test host app) as a process.
@Suite(.serialized)
struct ClaudeHelperTests {
    private let helper = Bundle.main.bundleURL.appending(path: "Contents/Helpers/easynotch-claude")

    private struct Result {
        var status: Int32
        var stdout: Data
        var seconds: TimeInterval
    }

    /// A short fake HOME: Unix socket paths are limited to 104 bytes.
    private func makeHome() -> URL {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let name = String((0..<6).map { _ in chars.randomElement()! })
        let url = URL(fileURLWithPath: "/tmp/enh-\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func run(_ arguments: [String], stdin: String, home: URL) throws -> Result {
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let inPipe = Pipe(), outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        let start = Date()
        try process.run()
        try inPipe.fileHandleForWriting.write(contentsOf: Data(stdin.utf8))
        try inPipe.fileHandleForWriting.close()
        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, stdout: out, seconds: Date().timeIntervalSince(start))
    }

    private let bashInput = #"{"tool_name":"Bash","tool_input":{"command":"ls"},"cwd":"/tmp/demo"}"#

    @Test func helperIsBundled() {
        #expect(FileManager.default.isExecutableFile(atPath: helper.path))
    }

    @Test func permissionWithoutAppPrintsNothing() throws {
        let home = makeHome(); defer { try? FileManager.default.removeItem(at: home) }
        let r = try run(["permission"], stdin: bashInput, home: home)
        #expect(r.status == 0)
        #expect(r.stdout.isEmpty)
        #expect(r.seconds < 2)
    }

    @Test func askUserQuestionPrintsNothing() throws {
        let home = makeHome(); defer { try? FileManager.default.removeItem(at: home) }
        let r = try run(["permission"], stdin: #"{"tool_name":"AskUserQuestion","tool_input":{}}"#, home: home)
        #expect(r.status == 0)
        #expect(r.stdout.isEmpty)
        #expect(r.seconds < 2)
    }

    @Test func statuslineThenRunsOriginalWithoutApp() throws {
        let home = makeHome(); defer { try? FileManager.default.removeItem(at: home) }
        let r = try run(["statusline", "--then", "cat >/dev/null; echo hi"], stdin: "{}", home: home)
        #expect(r.status == 0)
        #expect(String(decoding: r.stdout, as: UTF8.self) == "hi\n")
        #expect(r.seconds < 2)
    }

    @Test func permissionGetsAllowFromServer() throws {
        let home = makeHome(); defer { try? FileManager.default.removeItem(at: home) }
        let socket = ClaudeBridgeMessage.socketURL(
            appSupport: home.appendingPathComponent("Library/Application Support", isDirectory: true))
        try FileManager.default.createDirectory(
            at: socket.deletingLastPathComponent(), withIntermediateDirectories: true)
        let server = ClaudeBridgeServer(socketURL: socket)
        server.onMessage = { _, connection in connection.reply(.decision(allow: true)) }
        try server.start()
        defer { server.stop() }

        let r = try run(["permission"], stdin: bashInput, home: home)
        #expect(r.status == 0)
        let json = try JSONSerialization.jsonObject(with: r.stdout) as? [String: Any]
        let output = json?["hookSpecificOutput"] as? [String: Any]
        let decision = output?["decision"] as? [String: Any]
        #expect(decision?["behavior"] as? String == "allow")
    }
}
