import Foundation
import Testing

@testable import EasyNotch

/// Records what the service sends, instead of using a real socket.
private final class FakeConnection: ClaudeConnection, @unchecked Sendable {
    let id = UUID()
    private(set) var replies: [ClaudeBridgeMessage] = []
    private(set) var closeCount = 0
    func reply(_ message: ClaudeBridgeMessage) { replies.append(message) }
    func close() { closeCount += 1 }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_000_000)
}

private func request(_ summary: String) -> ClaudeBridgeMessage {
    .permissionRequest(tool: "Bash", summary: summary, project: "demo")
}

@Suite struct ClaudeServiceTests {
    private func make(
        _ defaults: UserDefaults, clock: Clock = Clock()
    ) -> (ClaudeService, AppSettings, Clock) {
        let settings = AppSettings(defaults: defaults)
        return (ClaudeService(settings: settings, now: { clock.date }), settings, clock)
    }

    @Test func requestsQueueOldestFirst() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            for name in ["a", "b", "c"] { service.receive(request(name), from: FakeConnection()) }
            #expect(service.pending.map(\.summary) == ["a", "b", "c"])
        }
    }

    @Test func allowRepliesToTheRightConnectionAndRemovesIt() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            let first = FakeConnection(), second = FakeConnection(), third = FakeConnection()
            service.receive(request("a"), from: first)
            service.receive(request("b"), from: second)
            service.receive(request("c"), from: third)
            service.allow(second.id)
            #expect(second.replies == [.decision(allow: true)])
            #expect(first.replies.isEmpty && third.replies.isEmpty)
            #expect(service.pending.count == 2)
        }
    }

    @Test func denyRepliesFalse() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            let connection = FakeConnection()
            service.receive(request("a"), from: connection)
            service.deny(connection.id)
            #expect(connection.replies == [.decision(allow: false)])
            #expect(service.pending.isEmpty)
        }
    }

    @Test func answeringAnUnknownIdDoesNothing() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            let connection = FakeConnection()
            service.receive(request("a"), from: connection)
            service.allow(UUID())
            #expect(connection.replies.isEmpty)
            #expect(service.pending.count == 1)
        }
    }

    @Test func hangupRemovesRequestWithoutReply() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            let connection = FakeConnection()
            service.receive(request("a"), from: connection)
            service.connectionClosed(connection.id)
            #expect(service.pending.isEmpty)
            #expect(connection.replies.isEmpty)
        }
    }

    @Test func usageUpdatesTimestampAndKeepsMissingWindowMissing() {
        withIsolatedDefaults { defaults in
            let (service, _, clock) = make(defaults)
            let window = UsageWindow(usedPercentage: 40, resetsAt: clock.date.addingTimeInterval(3600))
            service.receive(.usage(fiveHour: nil, sevenDay: window), from: FakeConnection())
            #expect(service.usage?.fiveHour == nil)
            #expect(service.usage?.sevenDay == window)
            #expect(service.usage?.updatedAt == clock.date)
        }
    }

    @Test func alertClearsOnAcknowledgeAndReturnsOnNewRequest() {
        withIsolatedDefaults { defaults in
            let (service, _, _) = make(defaults)
            #expect(!service.showsAlert)
            service.receive(request("a"), from: FakeConnection())
            #expect(service.showsAlert)
            service.acknowledgeAlerts()
            #expect(!service.showsAlert)
            service.receive(request("b"), from: FakeConnection())
            #expect(service.showsAlert)
        }
    }

    @Test func hiddenTabClosesRequestsImmediately() {
        withIsolatedDefaults { defaults in
            let (service, settings, _) = make(defaults)
            settings.hiddenModules = ["claude"]
            let connection = FakeConnection()
            service.receive(request("a"), from: connection)
            #expect(connection.closeCount == 1)
            #expect(connection.replies.isEmpty)
            #expect(service.pending.isEmpty)
        }
    }

    @Test func newFrontRequestIgnoresQuickAnswers() {
        withIsolatedDefaults { defaults in
            let (service, _, clock) = make(defaults)
            let first = FakeConnection(), second = FakeConnection()
            service.receive(request("a"), from: first)
            service.receive(request("b"), from: second)
            service.allow(first.id)
            clock.date = clock.date.addingTimeInterval(0.2)
            #expect(!service.canAnswer(second.id))
            service.allow(second.id)
            #expect(second.replies.isEmpty)
            clock.date = clock.date.addingTimeInterval(0.4)
            #expect(service.canAnswer(second.id))
            service.allow(second.id)
            #expect(second.replies == [.decision(allow: true)])
        }
    }
}
