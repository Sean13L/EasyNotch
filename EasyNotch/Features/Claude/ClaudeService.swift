import Foundation
import Observation

/// What the service needs from a socket connection. `Connection` conforms; tests use a fake.
nonisolated protocol ClaudeConnection: AnyObject, Sendable {
    var id: UUID { get }
    func reply(_ message: ClaudeBridgeMessage)
    func close()
}

extension Connection: ClaudeConnection {}

/// One permission request waiting for an answer. Its id is the connection's id.
struct ClaudeRequest: Identifiable, Equatable {
    let id: UUID
    let tool: String
    let summary: String
    let project: String
    let receivedAt: Date
}

/// The latest rate-limit numbers from Claude Code. A window that was never reported stays nil.
struct ClaudeUsage: Equatable {
    var fiveHour: UsageWindow?
    var sevenDay: UsageWindow?
    var updatedAt: Date
}

/// The app side of the Claude Code integration: a first-in-first-out queue of permission
/// requests (one per open socket connection), the latest usage, and the wing-alert state.
@Observable
final class ClaudeService {
    /// Whenever a different request becomes the front of the queue (an answer, a hangup, or
    /// a first arrival), it ignores answers for this long, so a click or keypress aimed at
    /// the old request can't land on the new one.
    static let answerGuard: TimeInterval = 0.5

    /// Requests waiting for an answer, oldest first.
    private(set) var pending: [ClaudeRequest] = []
    private(set) var usage: ClaudeUsage?
    private(set) var setupStatus: ClaudeSetup.Status = .disconnected
    /// True when there are waiting requests the user hasn't seen since the last new one.
    var showsAlert: Bool { !pending.isEmpty && !alertAcknowledged }

    private var alertAcknowledged = false

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let makeSetup: () -> ClaudeSetup
    @ObservationIgnored private var connections: [UUID: ClaudeConnection] = [:]
    @ObservationIgnored private var frontID: UUID?
    @ObservationIgnored private var frontSince = Date.distantPast
    @ObservationIgnored private let socketURLOverride: URL?
    @ObservationIgnored private var server: ClaudeBridgeServer?
    /// R5: `NotchModule.claude` doesn't exist yet; the tab's raw name stands in for it.
    @ObservationIgnored private let moduleName = "claude"

    /// `setup` is injectable so tests never touch the real `~/.claude`.
    init(
        settings: AppSettings, now: @escaping () -> Date = Date.init,
        setup: @escaping () -> ClaudeSetup = { ClaudeSetup.live() },
        socketURL: URL? = nil
    ) {
        self.settings = settings
        self.now = now
        self.makeSetup = setup
        self.socketURLOverride = socketURL
        watchHiddenTab()
    }

    /// Reads whether Claude Code is connected and, if so, starts listening. Called once at launch.
    func activate() {
        refreshStatus()
        guard setupStatus == .connected else { return }
        do {
            try startServer()
        } catch {
            Log.claude.error("bridge failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    func acknowledgeAlerts() {
        alertAcknowledged = true
    }

    func canAnswer(_ id: UUID) -> Bool {
        // Only the front request can be answered, and not right after it became the front.
        guard pending.first?.id == id else { return false }
        return now().timeIntervalSince(frontSince) >= Self.answerGuard
    }

    func allow(_ id: UUID) { answer(id, allow: true) }
    func deny(_ id: UUID) { answer(id, allow: false) }

    /// Adds our hook to Claude Code's settings and starts listening.
    func connect() throws {
        try makeSetup().connect()
        refreshStatus()
        try startServer()
    }

    /// Removes our hook and stops listening. Stopping closes every waiting connection, so
    /// those requests fall back to Claude Code's own terminal prompt.
    func disconnect() throws {
        try makeSetup().disconnect()
        refreshStatus()
        server?.stop()
        server = nil
        closeAllPending()
    }

    // MARK: - Messages from the server

    func receive(_ message: ClaudeBridgeMessage, from connection: ClaudeConnection) {
        switch message {
        case .permissionRequest(let tool, let summary, let project):
            // A hidden tab means the user doesn't want prompts here: closing the connection
            // makes the helper fall back to the terminal prompt.
            // No server running means this message was already in flight when we stopped, and
            // no hangup will ever come for it.
            guard server != nil, !settings.hiddenModules.contains(moduleName) else {
                connection.close()
                return
            }
            Log.claude.info("request \(tool, privacy: .public)")
            connections[connection.id] = connection
            pending.append(ClaudeRequest(
                id: connection.id, tool: tool, summary: summary, project: project, receivedAt: now()))
            alertAcknowledged = false
            updateFront()
        case .usage(let fiveHour, let sevenDay):
            usage = ClaudeUsage(fiveHour: fiveHour, sevenDay: sevenDay, updatedAt: now())
            connection.close()
        case .decision:
            connection.close()  // only the app sends these
        }
    }

    /// The helper hung up (Claude Code was stopped, or the user answered in the terminal).
    func connectionClosed(_ id: UUID) {
        connections[id] = nil
        pending.removeAll { $0.id == id }
        updateFront()
    }

    // MARK: - Private

    private func answer(_ id: UUID, allow: Bool) {
        guard canAnswer(id), let connection = connections[id] else { return }
        connection.reply(.decision(allow: allow))
        connections[id] = nil
        pending.removeAll { $0.id == id }
        updateFront()
    }

    /// Restarts the answer guard when a different request is now first in line.
    private func updateFront() {
        guard pending.first?.id != frontID else { return }
        frontID = pending.first?.id
        frontSince = now()
    }

    /// Closes every waiting connection without a reply, so Claude Code falls back to its
    /// own terminal prompt instead of waiting on a request nobody can see.
    private func closeAllPending() {
        for connection in connections.values { connection.close() }
        connections.removeAll()
        pending.removeAll()
        updateFront()
    }

    /// When the Claude tab is hidden, waiting requests would be invisible: hand them back.
    private func watchHiddenTab() {
        withObservationTracking {
            _ = settings.hiddenModules
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.settings.hiddenModules.contains(self.moduleName) { self.closeAllPending() }
                self.watchHiddenTab()
            }
        }
    }

    private func refreshStatus() {
        setupStatus = makeSetup().status()
    }

    private func startServer() throws {
        guard server == nil else { return }
        let socketURL: URL
        if let override = socketURLOverride {
            socketURL = override
        } else {
            do {
                let support = try FileManager.default.url(
                    for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                socketURL = ClaudeBridgeMessage.socketURL(appSupport: support)
            } catch {
                Log.claude.error("no Application Support folder: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        let server = ClaudeBridgeServer(socketURL: socketURL)
        // These run on the server's queue; hop to the main actor before touching our state.
        server.onMessage = { [weak self] message, connection in
            Task { @MainActor in self?.receive(message, from: connection) }
        }
        server.onHangup = { [weak self] id in
            Task { @MainActor in self?.connectionClosed(id) }
        }
        try server.start()
        self.server = server
        Log.claude.info("bridge listening")
    }
}
