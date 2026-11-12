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
    /// After an answer, the next request in line ignores answers for this long, so a click
    /// aimed at the old request can't land on a new one that just slid into its place.
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
    @ObservationIgnored private var lastAnswerAt: Date?
    @ObservationIgnored private var server: ClaudeBridgeServer?
    /// R5: `NotchModule.claude` doesn't exist yet; the tab's raw name stands in for it.
    @ObservationIgnored private let moduleName = "claude"

    /// `setup` is injectable so tests never touch the real `~/.claude`.
    init(
        settings: AppSettings, now: @escaping () -> Date = Date.init,
        setup: @escaping () -> ClaudeSetup = { ClaudeSetup.live() }
    ) {
        self.settings = settings
        self.now = now
        self.makeSetup = setup
    }

    /// Reads whether Claude Code is connected and, if so, starts listening. Called once at launch.
    func activate() {
        refreshStatus()
        if setupStatus == .connected { startServer() }
    }

    func acknowledgeAlerts() {
        alertAcknowledged = true
    }

    func canAnswer(_ id: UUID) -> Bool {
        guard pending.contains(where: { $0.id == id }) else { return false }
        if let last = lastAnswerAt, now().timeIntervalSince(last) < Self.answerGuard { return false }
        return true
    }

    func allow(_ id: UUID) { answer(id, allow: true) }
    func deny(_ id: UUID) { answer(id, allow: false) }

    /// Adds our hook to Claude Code's settings and starts listening.
    func connect() throws {
        try makeSetup().connect()
        refreshStatus()
        startServer()
    }

    /// Removes our hook and stops listening. Stopping closes every waiting connection, so
    /// those requests fall back to Claude Code's own terminal prompt.
    func disconnect() throws {
        try makeSetup().disconnect()
        refreshStatus()
        server?.stop()
        server = nil
        connections.removeAll()
        pending.removeAll()
    }

    // MARK: - Messages from the server

    func receive(_ message: ClaudeBridgeMessage, from connection: ClaudeConnection) {
        switch message {
        case .permissionRequest(let tool, let summary, let project):
            // A hidden tab means the user doesn't want prompts here: closing the connection
            // makes the helper fall back to the terminal prompt.
            guard !settings.hiddenModules.contains(moduleName) else {
                connection.close()
                return
            }
            Log.claude.info("request \(tool, privacy: .public)")
            connections[connection.id] = connection
            pending.append(ClaudeRequest(
                id: connection.id, tool: tool, summary: summary, project: project, receivedAt: now()))
            alertAcknowledged = false
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
    }

    // MARK: - Private

    private func answer(_ id: UUID, allow: Bool) {
        guard canAnswer(id), let connection = connections[id] else { return }
        connection.reply(.decision(allow: allow))
        connections[id] = nil
        pending.removeAll { $0.id == id }
        lastAnswerAt = now()
    }

    private func refreshStatus() {
        setupStatus = makeSetup().status()
    }

    private func startServer() {
        guard server == nil, let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return }
        let server = ClaudeBridgeServer(socketURL: ClaudeBridgeMessage.socketURL(appSupport: support))
        // These run on the server's queue; hop to the main actor before touching our state.
        server.onMessage = { [weak self] message, connection in
            Task { @MainActor in self?.receive(message, from: connection) }
        }
        server.onHangup = { [weak self] id in
            Task { @MainActor in self?.connectionClosed(id) }
        }
        do {
            try server.start()
            self.server = server
            Log.claude.info("bridge listening")
        } catch {
            Log.claude.error("bridge failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }
}
