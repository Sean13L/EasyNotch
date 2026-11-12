import Darwin
import Foundation
import Testing
@testable import EasyNotch

/// Thread-safe holder for values the server's queue hands to the test.
private nonisolated final class Box<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}

private nonisolated final class WeakConnection: @unchecked Sendable {
    weak var ref: Connection?
    init(_ c: Connection) { ref = c }
}

/// A short temporary folder: Unix socket paths are limited to 104 bytes.
private struct TempSocket {
    let folder: URL
    let socket: URL

    init() {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let name = String((0..<6).map { _ in chars.randomElement()! })
        folder = URL(fileURLWithPath: "/tmp/en-\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        socket = folder.appendingPathComponent("s.sock")
    }

    func cleanUp() { try? FileManager.default.removeItem(at: folder) }
}

private let request = ClaudeBridgeMessage.permissionRequest(tool: "Bash", summary: "ls", project: "demo")

/// Opens a raw client connection, for tests that need to misbehave.
private func rawConnect(_ url: URL) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let path = url.path
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        _ = path.withCString { strncpy(raw.baseAddress!.assumingMemoryBound(to: CChar.self), $0, raw.count - 1) }
    }
    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard result == 0 else { close(fd); return nil }
    var on: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    return fd
}

struct ClaudeBridgeRoundTripTests {
    @Test func askGetsTheServersReply() throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        server.onMessage = { _, connection in connection.reply(.decision(allow: true)) }
        try server.start()
        defer { server.stop() }

        #expect(ClaudeBridgeClient.ask(request, to: temp.socket) == .decision(allow: true))
    }

    @Test func askReturnsNilWithoutServer() {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let start = Date()
        #expect(ClaudeBridgeClient.ask(request, to: temp.socket) == nil)
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test func serverStoppingMidRequestReturnsNil() throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        server.onMessage = { [unowned server] _, _ in server.stop() }
        try server.start()
        defer { server.stop() }

        #expect(ClaudeBridgeClient.ask(request, to: temp.socket) == nil)
    }

    @Test func clientHangupIsReported() async throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        let seen = Box<UUID?>(nil)
        try await confirmation(expectedCount: 1) { hungUp in
            let fired = Box(false)
            server.onMessage = { _, connection in seen.value = connection.id }
            server.onHangup = { id in
                #expect(id == seen.value)
                fired.value = true
                hungUp()
            }
            try server.start()
            #expect(ClaudeBridgeClient.send(request, to: temp.socket))
            // Wait up to 2 seconds for the hangup.
            for _ in 0..<40 where !fired.value { try? await Task.sleep(for: .milliseconds(50)) }
        }
        server.stop()
    }

    @Test func serverSideCloseDoesNotReportHangup() async throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        try await confirmation(expectedCount: 0) { hungUp in
            server.onMessage = { _, connection in
                connection.reply(.decision(allow: false))
                connection.reply(.decision(allow: false))  // second call must be harmless
                connection.close()
            }
            server.onHangup = { _ in hungUp() }
            try server.start()
            #expect(ClaudeBridgeClient.ask(request, to: temp.socket) == .decision(allow: false))
            try? await Task.sleep(for: .milliseconds(300))
        }
        server.stop()
    }

    @Test func connectionsAreFreedAfterReplyAndAfterHangup() async throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        let weakRefs = Box<[WeakConnection]>([])
        let replyNext = Box(true)
        server.onMessage = { _, connection in
            weakRefs.value.append(WeakConnection(connection))
            if replyNext.value { connection.reply(.decision(allow: true)) }
        }
        try server.start()
        defer { server.stop() }

        #expect(ClaudeBridgeClient.ask(request, to: temp.socket) == .decision(allow: true))
        replyNext.value = false
        #expect(ClaudeBridgeClient.send(request, to: temp.socket))  // peer hangs up
        for _ in 0..<40 where weakRefs.value.count < 2 || weakRefs.value.contains(where: { $0.ref != nil }) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(weakRefs.value.count == 2)
        #expect(weakRefs.value.allSatisfy { $0.ref == nil })
    }

    @Test func onlyTheFirstLineOfAConnectionIsDelivered() async throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        let count = Box(0)
        server.onMessage = { _, _ in count.value += 1 }
        try server.start()
        defer { server.stop() }

        let fd = try #require(rawConnect(temp.socket))
        defer { close(fd) }
        let line = try request.encodeLine()
        var twoLines = line
        twoLines.append(line)
        _ = twoLines.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        try await Task.sleep(for: .milliseconds(200))
        _ = line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }  // and a later one
        try await Task.sleep(for: .milliseconds(200))
        #expect(count.value == 1)
    }

    @Test func stoppingMarksConnectionsClosed() async throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        let seen = Box<Connection?>(nil)
        server.onMessage = { _, connection in seen.value = connection }
        try server.start()

        let fd = try #require(rawConnect(temp.socket))
        defer { close(fd) }
        let line = try request.encodeLine()
        _ = line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        for _ in 0..<40 where seen.value == nil { try await Task.sleep(for: .milliseconds(50)) }
        let connection = try #require(seen.value)
        #expect(!connection.isClosed)
        server.stop()
        #expect(connection.isClosed)
    }

    @Test func oversizedLineClosesConnection() throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        let called = Box(false)
        server.onMessage = { _, _ in called.value = true }
        try server.start()
        defer { server.stop() }

        let fd = try #require(rawConnect(temp.socket))
        defer { close(fd) }
        let junk = [UInt8](repeating: 0x61, count: 70_000)
        var offset = 0
        while offset < junk.count {
            let n = junk[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n <= 0 { break }  // server already closed on us
            offset += n
        }
        var byte: UInt8 = 0
        #expect(read(fd, &byte, 1) <= 0)  // 0 = clean close, -1 = reset
        #expect(called.value == false)
    }

    @Test func startRemovesLeftoverSocketAndSetsPermissions() throws {
        let temp = TempSocket(); defer { temp.cleanUp() }
        try Data("old".utf8).write(to: temp.socket)
        let server = ClaudeBridgeServer(socketURL: temp.socket)
        try server.start()
        defer { server.stop() }

        func mode(_ url: URL) throws -> Int {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs[.posixPermissions] as? NSNumber)?.intValue ?? -1
        }
        #expect(try mode(temp.folder) == 0o700)
        #expect(try mode(temp.socket) == 0o600)
    }
}
