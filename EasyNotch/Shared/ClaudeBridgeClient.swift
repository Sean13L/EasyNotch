import Darwin
import Foundation

// Foundation/Darwin only: this file is also compiled into the command-line helper.

/// The helper's side of the socket: connect, write one line, optionally wait for one reply line.
/// Everything here blocks on purpose; the hook's own `timeout` is the only limit.
nonisolated enum ClaudeBridgeClient {
    /// Sends a message and returns without waiting for a reply. False if it can't connect or write.
    static func send(_ message: ClaudeBridgeMessage, to socket: URL) -> Bool {
        guard let fd = connectAndWrite(message, to: socket) else { return false }
        close(fd)
        return true
    }

    /// Sends a message and blocks until one reply line arrives.
    /// Nil if it can't connect, the connection closes first, or the reply is invalid.
    static func ask(_ message: ClaudeBridgeMessage, to socket: URL) -> ClaudeBridgeMessage? {
        guard let fd = connectAndWrite(message, to: socket) else { return nil }
        defer { close(fd) }

        var line = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while line.count <= ClaudeBridgeMessage.maxLineBytes {
            let n = read(fd, &chunk, chunk.count)
            if n < 0 && errno == EINTR { continue }
            if n <= 0 { return nil }  // closed (or failed) before a full line arrived
            if let newline = chunk[..<n].firstIndex(of: 0x0A) {
                line.append(contentsOf: chunk[..<newline])
                return try? ClaudeBridgeMessage.decode(line: line)
            }
            line.append(contentsOf: chunk[..<n])
        }
        return nil
    }

    private static func connectAndWrite(_ message: ClaudeBridgeMessage, to socket: URL) -> Int32? {
        guard let data = try? message.encodeLine() else { return nil }
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        // Without this, writing to a closed peer would kill the process with SIGPIPE.
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socket.path
        guard path.utf8.count < MemoryLayout.size(ofValue: addr.sun_path) else { close(fd); return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            _ = path.withCString { strncpy(raw.baseAddress!.assumingMemoryBound(to: CChar.self), $0, raw.count - 1) }
        }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { close(fd); return nil }

        var offset = 0
        while offset < data.count {
            let n = data[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n < 0 && errno == EINTR { continue }
            if n <= 0 { close(fd); return nil }
            offset += n
        }
        return fd
    }
}
