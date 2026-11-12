import Foundation
import Testing

@testable import EasyNotch

/// Records what the service sends, instead of using a real socket.
private final class FakeConnection: ClaudeConnection, @unchecked Sendable {
    let id = UUID()
    private(set) var replies: [ClaudeBridgeMessage] = []
    private(set) var closeCount = 0
    var isClosed = false
    func reply(_ message: ClaudeBridgeMessage) { replies.append(message) }
    func close() { closeCount += 1 }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_000_000)
}

private func request(_ summary: String) -> ClaudeBridgeMessage {
    .permissionRequest(tool: "Bash", summary: summary, project: "demo")
}

/// A service wired to a temporary settings file and a short temporary socket, never to
/// ~/.claude or the real Application Support folder. `connect()` has already run.
private struct Rig {
    let service: ClaudeService
    let settings: AppSettings
    let clock = Clock()
    let folder: URL
    let settingsURL: URL

    init(_ defaults: UserDefaults, connected: Bool = true) throws {
        // Unix socket paths max out near 104 bytes, so keep this short.
        folder = URL(fileURLWithPath: "/tmp/en-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        settingsURL = folder.appending(path: "settings.json")
        try Data("{}".utf8).write(to: settingsURL)
        let setupURL = settingsURL
        let clock = self.clock
        settings = AppSettings(defaults: defaults)
        service = ClaudeService(
            settings: settings, defaults: defaults, now: { clock.date },
            setup: { ClaudeSetup(settingsURL: setupURL, helperPath: "/tmp/easynotch-claude") },
            socketURL: folder.appending(path: "s.sock"))
        if connected { try service.connect() }
    }

    func cleanup() {
        try? service.disconnect()
        try? FileManager.default.removeItem(at: folder)
    }

    func wait(_ seconds: TimeInterval) { clock.date = clock.date.addingTimeInterval(seconds) }
}

@Suite struct ClaudeServiceTests {
    @Test func requestsQueueOldestFirst() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            for name in ["a", "b", "c"] { rig.service.receive(request(name), from: FakeConnection()) }
            #expect(rig.service.pending.map(\.summary) == ["a", "b", "c"])
        }
    }

    @Test func allowRepliesToTheFrontConnectionAndRemovesIt() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let first = FakeConnection(), second = FakeConnection(), third = FakeConnection()
            rig.service.receive(request("a"), from: first)
            rig.service.receive(request("b"), from: second)
            rig.service.receive(request("c"), from: third)
            rig.wait(1)
            rig.service.allow(first.id)
            #expect(first.replies == [.decision(allow: true)])
            #expect(second.replies.isEmpty && third.replies.isEmpty)
            #expect(rig.service.pending.count == 2)
        }
    }

    @Test func onlyTheFrontRequestCanBeAnswered() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let first = FakeConnection(), second = FakeConnection()
            rig.service.receive(request("a"), from: first)
            rig.service.receive(request("b"), from: second)
            rig.wait(1)
            rig.service.allow(second.id)
            #expect(second.replies.isEmpty)
            #expect(rig.service.pending.count == 2)
        }
    }

    @Test func denyRepliesFalse() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.wait(1)
            rig.service.deny(connection.id)
            #expect(connection.replies == [.decision(allow: false)])
            #expect(rig.service.pending.isEmpty)
        }
    }

    @Test func answeringAnUnknownIdDoesNothing() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.wait(1)
            rig.service.allow(UUID())
            #expect(connection.replies.isEmpty)
            #expect(rig.service.pending.count == 1)
        }
    }

    @Test func hangupRemovesRequestWithoutReply() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.service.connectionClosed(connection.id)
            #expect(rig.service.pending.isEmpty)
            #expect(connection.replies.isEmpty)
        }
    }

    @Test func usageUpdatesTimestampAndKeepsMissingWindowMissing() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let window = UsageWindow(usedPercentage: 40, resetsAt: rig.clock.date.addingTimeInterval(3600))
            rig.service.receive(.usage(fiveHour: nil, sevenDay: window), from: FakeConnection())
            #expect(rig.service.usage?.fiveHour == nil)
            #expect(rig.service.usage?.sevenDay == window)
            #expect(rig.service.usage?.updatedAt == rig.clock.date)
        }
    }

    @Test func usageIsRememberedAcrossRelaunch() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let window = UsageWindow(usedPercentage: 42, resetsAt: Date(timeIntervalSince1970: 1_000_500))
            rig.service.receive(.usage(fiveHour: window, sevenDay: nil), from: FakeConnection())
            // A fresh service on the same preferences, as after quitting and reopening EasyNotch.
            let relaunched = ClaudeService(settings: rig.settings, defaults: defaults)
            #expect(relaunched.usage == rig.service.usage)
            #expect(relaunched.usage?.fiveHour == window)
            #expect(relaunched.usage?.sevenDay == nil)
        }
    }

    @Test func disconnectForgetsSavedUsage() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let window = UsageWindow(usedPercentage: 42, resetsAt: Date(timeIntervalSince1970: 1_000_500))
            rig.service.receive(.usage(fiveHour: window, sevenDay: nil), from: FakeConnection())
            try rig.service.disconnect()
            #expect(rig.service.usage == nil)
            #expect(ClaudeService(settings: rig.settings, defaults: defaults).usage == nil)
        }
    }

    @Test func alertClearsWhenTheTabShowsAndReturnsOnNewRequest() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            #expect(!rig.service.showsAlert)
            rig.service.receive(request("a"), from: FakeConnection())
            #expect(rig.service.showsAlert)
            rig.service.tabAppeared()
            #expect(!rig.service.showsAlert)
            rig.service.tabDisappeared()
            #expect(!rig.service.showsAlert)
            rig.service.receive(request("b"), from: FakeConnection())
            #expect(rig.service.showsAlert)
        }
    }

    @Test func requestArrivingWhileTheTabShowsRaisesNoAlert() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            rig.service.tabAppeared()
            rig.service.receive(request("a"), from: FakeConnection())
            #expect(!rig.service.showsAlert)
            // Two notches (two screens) can show the tab; it counts as shown until both go.
            rig.service.tabAppeared()
            rig.service.tabDisappeared()
            rig.service.receive(request("b"), from: FakeConnection())
            #expect(!rig.service.showsAlert)
            rig.service.tabDisappeared()
            rig.service.receive(request("c"), from: FakeConnection())
            #expect(rig.service.showsAlert)
        }
    }

    @Test func requestWithNoVisibleNotchIsClosed() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            rig.service.isNotchVisible = { false }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            #expect(connection.closeCount == 1)
            #expect(connection.replies.isEmpty)
            #expect(rig.service.pending.isEmpty)
        }
    }

    @Test func notchesDisappearingClosesWaitingRequests() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.service.notchVisibilityChanged(true)
            #expect(rig.service.pending.count == 1)
            rig.service.notchVisibilityChanged(false)
            #expect(rig.service.pending.isEmpty)
            #expect(connection.closeCount == 1)
            #expect(connection.replies.isEmpty)
        }
    }

    @Test func alreadyClosedConnectionIsIgnored() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            connection.isClosed = true
            rig.service.receive(request("a"), from: connection)
            #expect(rig.service.pending.isEmpty)
        }
    }

    @Test func pendingRequestsAreCapped() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            for i in 0..<ClaudeService.maxPending { rig.service.receive(request("\(i)"), from: FakeConnection()) }
            let extra = FakeConnection()
            rig.service.receive(request("extra"), from: extra)
            #expect(rig.service.pending.count == ClaudeService.maxPending)
            #expect(ClaudeService.maxPending == 32)
            #expect(extra.closeCount == 1)
            #expect(extra.replies.isEmpty)
        }
    }

    @Test func hiddenTabClosesRequestsImmediately() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            rig.settings.hiddenModules = ["claude"]
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            #expect(connection.closeCount == 1)
            #expect(connection.replies.isEmpty)
            #expect(rig.service.pending.isEmpty)
        }
    }

    @Test func hidingTheTabClosesWaitingRequests() async throws {
        try await withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.settings.hiddenModules = ["claude"]
            for _ in 0..<50 where !rig.service.pending.isEmpty { await Task.yield() }
            #expect(rig.service.pending.isEmpty)
            #expect(connection.closeCount == 1)
            #expect(connection.replies.isEmpty)
        }
    }

    @Test func newFrontRequestIgnoresQuickAnswers() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let first = FakeConnection(), second = FakeConnection()
            rig.service.receive(request("a"), from: first)
            rig.service.receive(request("b"), from: second)
            rig.wait(1)
            rig.service.allow(first.id)
            rig.wait(0.2)
            #expect(!rig.service.canAnswer(second.id))
            rig.service.allow(second.id)
            #expect(second.replies.isEmpty)
            rig.wait(0.4)
            #expect(rig.service.canAnswer(second.id))
            rig.service.allow(second.id)
            #expect(second.replies == [.decision(allow: true)])
        }
    }

    @Test func frontChangedByHangupRestartsTheGuard() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let first = FakeConnection(), second = FakeConnection()
            rig.service.receive(request("a"), from: first)
            rig.service.receive(request("b"), from: second)
            rig.wait(1)
            rig.service.connectionClosed(first.id)  // e.g. the user pressed Ctrl-C in the terminal
            rig.wait(0.1)
            rig.service.allow(second.id)
            #expect(second.replies.isEmpty)
            rig.wait(0.5)
            rig.service.allow(second.id)
            #expect(second.replies == [.decision(allow: true)])
        }
    }

    @Test func arrivalIntoEmptyQueueIsGuarded() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            rig.wait(10)
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            rig.wait(0.1)
            #expect(!rig.service.canAnswer(connection.id))
            rig.wait(0.5)
            #expect(rig.service.canAnswer(connection.id))
        }
    }

    // MARK: Server lifecycle

    @Test func requestWithNoServerRunningIsClosed() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults, connected: false); defer { rig.cleanup() }
            let connection = FakeConnection()
            rig.service.receive(request("a"), from: connection)
            #expect(connection.closeCount == 1)
            #expect(rig.service.pending.isEmpty)
        }
    }

    @Test func connectAndDisconnectUpdateStatus() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults, connected: false); defer { rig.cleanup() }
            #expect(rig.service.setupStatus == .disconnected)
            try rig.service.connect()
            #expect(rig.service.setupStatus == .connected)
            try rig.service.disconnect()
            #expect(rig.service.setupStatus == .disconnected)
        }
    }

    @Test func connectThrowsWhenTheServerCannotStart() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults, connected: false); defer { rig.cleanup() }
            let tooLong = URL(fileURLWithPath: "/tmp/" + String(repeating: "x", count: 200) + "/s.sock")
            let service = ClaudeService(
                settings: rig.settings,
                setup: { ClaudeSetup(settingsURL: rig.settingsURL, helperPath: "/tmp/easynotch-claude") },
                socketURL: tooLong)
            #expect(throws: (any Error).self) { try service.connect() }
        }
    }

    @Test func activateListensOnlyWhenAlreadyConnected() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults, connected: false); defer { rig.cleanup() }
            rig.service.activate()
            #expect(rig.service.setupStatus == .disconnected)
            let c1 = FakeConnection()
            rig.service.receive(request("a"), from: c1)
            #expect(c1.closeCount == 1)  // not listening

            try ClaudeSetup(settingsURL: rig.settingsURL, helperPath: "/tmp/easynotch-claude").connect()
            rig.service.activate()
            #expect(rig.service.setupStatus == .connected)
            let c2 = FakeConnection()
            rig.service.receive(request("b"), from: c2)
            #expect(c2.closeCount == 0)
            #expect(rig.service.pending.count == 1)
        }
    }

    @Test func disconnectClosesEveryPendingConnection() throws {
        try withIsolatedDefaults { defaults in
            let rig = try Rig(defaults); defer { rig.cleanup() }
            let first = FakeConnection(), second = FakeConnection()
            rig.service.receive(request("a"), from: first)
            rig.service.receive(request("b"), from: second)
            try rig.service.disconnect()
            #expect(first.closeCount == 1 && second.closeCount == 1)
            #expect(first.replies.isEmpty && second.replies.isEmpty)
            #expect(rig.service.pending.isEmpty)
        }
    }
}

struct ClaudeUsageTextTests {
    @Test func resetAndUpdatedTexts() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ClaudeUsageView.resetText(now + 2 * 3600 + 10 * 60 + 5, now: now) == "resets in 2h 10m")
        #expect(ClaudeUsageView.resetText(now + 25 * 60, now: now) == "resets in 25m")
        // 1_800_000_000 is Friday 2027-01-15 08:00 UTC; 30 h later is Saturday.
        let utc = TimeZone(identifier: "UTC")!
        #expect(ClaudeUsageView.resetText(now + 30 * 3600, now: now, locale: Locale(identifier: "en_US"), timeZone: utc) == "resets Sat")
        #expect(ClaudeUsageView.percentText(130) == "100")
        #expect(ClaudeUsageView.percentText(-5) == "0")
        #expect(ClaudeUsageView.percentText(42.4) == "42")
        #expect(ClaudeUsageView.updatedText(now - 300, now: now) == "Updated 5 min ago")
        #expect(ClaudeUsageView.updatedText(now - 10, now: now) == "Updated just now")
    }

    @Test func aWindowPastItsResetShowsZero() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = UsageWindow(usedPercentage: 80, resetsAt: now - 1)
        let future = UsageWindow(usedPercentage: 80, resetsAt: now + 60)
        #expect(ClaudeUsageView.displayedPercent(past, now: now) == 0)
        #expect(ClaudeUsageView.displayedPercent(future, now: now) == 80)
        #expect(ClaudeUsageView.resetText(now - 1, now: now) == "reset")
    }
}
