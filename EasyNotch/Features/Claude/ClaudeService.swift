import Foundation
import Observation

/// What the service needs from a socket connection. `Connection` conforms; tests use a fake.
nonisolated protocol ClaudeConnection: AnyObject, Sendable {
    var id: UUID { get }
    /// True once the connection is closed (by either side). Safe to read from any thread.
    var isClosed: Bool { get }
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

/// A session where Claude just finished a reply and is waiting briefly for a next instruction.
/// Its id is the connection's id.
struct ClaudeFinished: Identifiable, Equatable {
    let id: UUID
    let message: String
    let project: String
}

/// The latest rate-limit numbers from Claude Code. A window that was never reported stays nil.
/// `Codable` so the last numbers survive a relaunch: Claude Code only sends them when its status
/// line redraws, which can be a long time while a session sits idle.
struct ClaudeUsage: Equatable, Codable {
    var fiveHour: UsageWindow?
    var sevenDay: UsageWindow?
    var updatedAt: Date
}

/// The app side of the Claude Code integration: a first-in-first-out queue of permission
/// requests (one per open socket connection), the latest usage, and the wing-alert state.
@Observable
final class ClaudeService {
    /// Whenever a different request becomes the front of the queue (an answer, a hangup, or
    /// a first arrival), it ignores answers for this long, so a click aimed at the old
    /// request can't land on the new one as the front changes under the pointer.
    static let answerGuard: TimeInterval = 0.5
    /// More waiting requests than this are handed straight back to the terminal.
    static let maxPending = 32
    /// How long a finished session waits for a reply before it's let go, so the terminal
    /// isn't paused for long. The clock stops while the answer card is open.
    static let finishedWait: Duration = .seconds(30)

    /// Requests waiting for an answer, oldest first.
    private(set) var pending: [ClaudeRequest] = []
    private(set) var usage: ClaudeUsage? {
        didSet { saveUsage() }
    }
    private(set) var setupStatus: ClaudeSetup.Status = .disconnected
    /// The latest session that finished a reply, while it waits for a next instruction.
    private(set) var finished: ClaudeFinished?
    /// Whether our Stop hook is installed (Settings: "Reply from the notch when Claude finishes").
    private(set) var repliesOnFinish = false
    /// True when there are waiting requests the user hasn't seen since the last new one, or a
    /// finished session waiting for a reply.
    var showsAlert: Bool { (!pending.isEmpty && !alertAcknowledged) || finished != nil }

    private var alertAcknowledged = false

    /// Whether any notch window is on screen. Set by `AppServices` (it asks the notch layer,
    /// which this feature can't see). With no notch visible, a request would wait unseen.
    @ObservationIgnored var isNotchVisible: () -> Bool = { true }

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let makeSetup: () -> ClaudeSetup
    @ObservationIgnored private var connections: [UUID: ClaudeConnection] = [:]
    @ObservationIgnored private var frontID: UUID?
    @ObservationIgnored private var frontSince = Date.distantPast
    @ObservationIgnored private let socketURLOverride: URL?
    @ObservationIgnored private var server: ClaudeBridgeServer?
    @ObservationIgnored private let moduleName = NotchModule.claude.rawValue
    /// How many open notches are showing the Claude tab right now (one per screen at most).
    @ObservationIgnored private var tabShowingCount = 0
    @ObservationIgnored private var finishedExpiry: Task<Void, Never>?

    /// `setup` is injectable so tests never touch the real `~/.claude`.
    init(
        settings: AppSettings, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
        setup: @escaping () -> ClaudeSetup = { ClaudeSetup.live() },
        socketURL: URL? = nil
    ) {
        self.settings = settings
        self.defaults = defaults
        self.now = now
        usage = Self.loadUsage(from: defaults)
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

    /// The Claude tab came on screen (`ClaudeView` appeared): its requests count as seen.
    /// Opening the notch on another tab doesn't, or a request could wait with no wing.
    func tabAppeared() {
        tabShowingCount += 1
        alertAcknowledged = true
    }

    func tabDisappeared() {
        tabShowingCount = max(0, tabShowingCount - 1)
    }

    /// Every notch window went away (lid closed with only the built-in display chosen, or
    /// hidden over a full-screen app): hand waiting requests back to the terminal.
    func notchVisibilityChanged(_ visible: Bool) {
        guard !visible, !pending.isEmpty else { return }
        Log.claude.info("no notch visible; returning requests to the terminal")
        closeAllPending()
    }

    func canAnswer(_ id: UUID) -> Bool {
        // Only the front request can be answered, and not right after it became the front.
        guard pending.first?.id == id else { return false }
        return now().timeIntervalSince(frontSince) >= Self.answerGuard
    }

    func allow(_ id: UUID) { answer(id, allow: true) }
    /// `note` reaches Claude as the reason, so it can try something else.
    func deny(_ id: UUID, note: String? = nil) { answer(id, allow: false, note: note) }

    /// Sends the user's next instruction to the finished session; Claude keeps going with it.
    func sendReply(_ text: String) {
        guard let finished, let connection = connections[finished.id] else { return }
        connection.reply(.reply(text: text))
        clearFinished()
    }

    /// Lets the finished session stop normally, giving the terminal back right away.
    func dismissFinished() {
        guard let finished else { return }
        connections[finished.id]?.close()
        clearFinished()
    }

    /// The answer card opened or closed: no letting go of the session while you're typing.
    func finishedCardVisible(_ visible: Bool) {
        finishedExpiry?.cancel()
        if !visible, finished != nil { startFinishedExpiry() }
    }

    /// Adds or removes the Stop hook, keeping everything else as it is.
    func setRepliesOnFinish(_ on: Bool) throws {
        try makeSetup().connect(replyOnFinish: on)
        refreshStatus()
    }

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
        usage = nil  // also forgets the saved numbers
    }

    // MARK: - Saved usage

    /// Only the two percentages, their reset times, and when they arrived. Never request data.
    private static let usageKey = "claude.lastUsage"

    private static func loadUsage(from defaults: UserDefaults) -> ClaudeUsage? {
        guard let data = defaults.data(forKey: usageKey) else { return nil }
        return try? JSONDecoder().decode(ClaudeUsage.self, from: data)
    }

    private func saveUsage() {
        if let usage, let data = try? JSONEncoder().encode(usage) {
            defaults.set(data, forKey: Self.usageKey)
        } else {
            defaults.removeObject(forKey: Self.usageKey)
        }
    }

    // MARK: - Messages from the server

    func receive(_ message: ClaudeBridgeMessage, from connection: ClaudeConnection) {
        switch message {
        case .permissionRequest(let tool, let summary, let project):
            // A hidden tab means the user doesn't want prompts here: closing the connection
            // makes the helper fall back to the terminal prompt.
            // No server running means this message was already in flight when we stopped, and
            // no hangup will ever come for it. The same goes for a connection that's already
            // closed (its server was stopped while this message hopped to the main actor).
            // With no notch on screen, or too many already waiting, nobody would see it.
            guard server != nil, !connection.isClosed, !settings.hiddenModules.contains(moduleName),
                  isNotchVisible(), pending.count < Self.maxPending
            else {
                connection.close()
                return
            }
            Log.claude.info("request \(tool, privacy: .public)")
            connections[connection.id] = connection
            pending.append(ClaudeRequest(
                id: connection.id, tool: tool, summary: summary, project: project, receivedAt: now()))
            // If the tab is on screen right now, the user is already looking at it.
            alertAcknowledged = tabShowingCount > 0
            updateFront()
        case .usage(let fiveHour, let sevenDay):
            usage = ClaudeUsage(fiveHour: fiveHour, sevenDay: sevenDay, updatedAt: now())
            connection.close()
        case .finished(let message, let project):
            guard server != nil, !connection.isClosed, !settings.hiddenModules.contains(moduleName), isNotchVisible()
            else {
                connection.close()
                return
            }
            // One at a time: a newer finished session replaces the older one, which just stops.
            dismissFinished()
            connections[connection.id] = connection
            finished = ClaudeFinished(id: connection.id, message: message, project: project)
            startFinishedExpiry()
        case .decision, .reply:
            connection.close()  // only the app sends these
        }
    }

    /// The helper hung up (Claude Code was stopped, or the user answered in the terminal).
    func connectionClosed(_ id: UUID) {
        connections[id] = nil
        if finished?.id == id { clearFinished() }
        pending.removeAll { $0.id == id }
        updateFront()
    }

    // MARK: - Private

    private func answer(_ id: UUID, allow: Bool, note: String? = nil) {
        guard canAnswer(id), let connection = connections[id] else { return }
        connection.reply(.decision(allow: allow, note: note))
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
        clearFinished()
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
        let setup = makeSetup()
        setupStatus = setup.status()
        repliesOnFinish = setupStatus == .connected && setup.repliesOnFinish()
    }

    private func clearFinished() {
        finishedExpiry?.cancel()
        finishedExpiry = nil
        if let id = finished?.id { connections[id] = nil }
        finished = nil
    }

    private func startFinishedExpiry() {
        finishedExpiry?.cancel()
        finishedExpiry = Task { [weak self] in
            try? await Task.sleep(for: Self.finishedWait)
            guard !Task.isCancelled else { return }
            self?.dismissFinished()
        }
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
