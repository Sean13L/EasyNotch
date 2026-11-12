import Darwin
import Foundation

/// The app's side of the socket. Runs on its own private serial queue so the main thread is
/// never blocked. Callbacks (`onMessage`, `onHangup`) run on that queue too.
///
/// Concurrency: `@unchecked Sendable` is safe because all mutable state (`listener`,
/// `connections`, `isRunning`) is only touched on `queue`. The two callbacks are set before
/// `start()` and not changed afterwards.
nonisolated final class ClaudeBridgeServer: @unchecked Sendable {
    var onMessage: @Sendable (ClaudeBridgeMessage, Connection) -> Void = { _, _ in }
    var onHangup: @Sendable (Connection.ID) -> Void = { _ in }

    private let socketURL: URL
    private let queue = DispatchQueue(label: "com.seanl.easynotch.claude-bridge")
    private let queueKey = DispatchSpecificKey<Bool>()
    private var listener: DispatchSourceRead?
    private var connections: [UUID: Connection] = [:]

    init(socketURL: URL) {
        self.socketURL = socketURL
        queue.setSpecific(key: queueKey, value: true)
    }

    deinit { stop() }

    /// Creates the folder (0700) and socket (0600), removing any leftover socket, and starts listening.
    func start() throws {
        try onQueue { try startLocked() }
    }

    /// Closes every connection and removes the socket file. Safe to call from a callback.
    func stop() {
        onQueue { stopLocked() }
    }

    // MARK: - Queue-confined

    /// Runs on the server queue; directly when already there, so callbacks can call `stop()`.
    private func onQueue<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true { return try work() }
        return try queue.sync(execute: work)
    }

    private func startLocked() throws {
        guard listener == nil else { return }
        let folder = socketURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        chmod(folder.path, 0o700)  // the folder may already exist with looser permissions
        unlink(socketURL.path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        func fail() -> POSIXError {
            let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            close(fd)
            return error
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketURL.path
        guard path.utf8.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw POSIXError(.ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            _ = path.withCString { strncpy(raw.baseAddress!.assumingMemoryBound(to: CChar.self), $0, raw.count - 1) }
        }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { throw fail() }
        chmod(path, 0o600)
        guard listen(fd, 8) == 0 else { throw fail() }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptPending(on: fd) }
        source.setCancelHandler { close(fd) }
        listener = source
        source.resume()
        Log.claude.info("Bridge server listening")
    }

    private func stopLocked() {
        guard let source = listener else { return }
        listener = nil
        source.cancel()
        for connection in connections.values { connection.closeLocked() }
        connections.removeAll()
        unlink(socketURL.path)
        Log.claude.info("Bridge server stopped")
    }

    private func acceptPending(on listenFD: Int32) {
        while true {
            let fd = accept(listenFD, nil, nil)
            if fd < 0 { return }  // EAGAIN: nothing more waiting
            var on: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

            let connection = Connection(fd: fd, queue: queue)
            connection.handlers = Connection.Handlers(
                message: { [weak self] message in self?.onMessage(message, connection) },
                hangup: { [weak self] in
                    self?.connections[connection.id] = nil
                    self?.onHangup(connection.id)
                },
                closed: { [weak self] in self?.connections[connection.id] = nil }
            )
            connections[connection.id] = connection
            connection.startReading()
            Log.claude.debug("Bridge connection opened")
        }
    }
}

/// One client connection. Reads lines until the peer hangs up or the server closes it.
///
/// Semantics: `onHangup` fires at most once, and only when the *peer* ended the connection.
/// Once `reply`, `close`, or an oversized/invalid line closes it, no hangup is reported.
/// `reply` and `close` are idempotent and safe after the peer has gone away.
nonisolated final class Connection: Identifiable, @unchecked Sendable {
    let id = UUID()

    struct Handlers {
        var message: @Sendable (ClaudeBridgeMessage) -> Void
        var hangup: @Sendable () -> Void
        var closed: @Sendable () -> Void
    }

    // All of the below is confined to `queue` (the server's serial queue).
    private let fd: Int32
    private let queue: DispatchQueue
    private var source: DispatchSourceRead?
    private var buffer = Data()
    private var isClosed = false
    var handlers = Handlers(message: { _ in }, hangup: {}, closed: {})

    init(fd: Int32, queue: DispatchQueue) {
        self.fd = fd
        self.queue = queue
    }

    /// Writes the message as one line, then closes the connection.
    func reply(_ message: ClaudeBridgeMessage) {
        queue.async { [self] in
            guard !isClosed, let data = try? message.encodeLine() else { return closeLocked() }
            writeAll(data)
            closeLocked()
        }
    }

    func close() {
        queue.async { [self] in closeLocked() }
    }

    // MARK: - Queue-confined

    func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.readAvailable() }
        // The descriptor is closed only here, after the source stops, so it can't be reused early.
        let fd = fd
        source.setCancelHandler { Darwin.close(fd) }
        self.source = source
        source.resume()
    }

    func closeLocked() {
        guard !isClosed else { return }
        isClosed = true
        source?.cancel()
        source = nil
        let closed = handlers.closed
        // Drop the handlers (they capture this connection) and the buffer, or it never frees.
        handlers = Handlers(message: { _ in }, hangup: {}, closed: {})
        buffer = Data()
        closed()
    }

    private func readAvailable() {
        guard !isClosed else { return }
        var chunk = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &chunk, chunk.count)
        if n < 0 && (errno == EAGAIN || errno == EINTR) { return }
        if n <= 0 {  // 0 = peer hung up, <0 = broken connection
            guard !isClosed else { return }
            let hangup = handlers.hangup
            closeLocked()
            hangup()
            return
        }
        buffer.append(contentsOf: chunk[..<n])
        while !isClosed, let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = try? ClaudeBridgeMessage.decode(line: Data(line)) else {
                Log.claude.error("Bridge connection sent an invalid line; closing")
                return closeLocked()
            }
            handlers.message(message)
        }
        if !isClosed && buffer.count > ClaudeBridgeMessage.maxLineBytes {
            Log.claude.error("Bridge line too long; closing")
            closeLocked()
        }
    }

    /// Blocking-style write on a non-blocking socket: waits briefly if the peer's buffer is full.
    private func writeAll(_ data: Data) {
        var offset = 0
        while offset < data.count {
            let n = data[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n > 0 { offset += n; continue }
            if n < 0 && errno == EINTR { continue }
            if n < 0 && errno == EAGAIN {
                var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                if poll(&pfd, 1, 1000) > 0 { continue }
            }
            return  // peer gone or stuck; nothing more to do (no SIGPIPE: SO_NOSIGPIPE is set)
        }
    }
}
