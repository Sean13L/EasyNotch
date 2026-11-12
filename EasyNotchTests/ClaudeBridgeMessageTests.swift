import Foundation
import Testing
@testable import EasyNotch

struct ClaudeBridgeMessageTests {
    let samples: [ClaudeBridgeMessage] = [
        .permissionRequest(tool: "Bash", summary: "echo a\necho b", project: "EasyNotch"),
        .usage(
            fiveHour: UsageWindow(usedPercentage: 42, resetsAt: Date(timeIntervalSince1970: 1_700_000_000)),
            sevenDay: nil),
        .decision(allow: true),
        .decision(allow: false),
    ]

    @Test func messagesRoundTripThroughOneLine() throws {
        for message in samples {
            let data = try message.encodeLine()
            #expect(data.last == 0x0A)
            #expect(data.filter { $0 == 0x0A }.count == 1)
            #expect(try ClaudeBridgeMessage.decode(line: data) == message)
        }
    }

    @Test func oversizedLineIsRejected() {
        let line = Data(repeating: 0x61, count: 65_537)
        #expect(throws: ClaudeBridgeError.tooLong) { try ClaudeBridgeMessage.decode(line: line) }
    }

    @Test func garbageIsRejected() {
        #expect(throws: ClaudeBridgeError.invalid) {
            try ClaudeBridgeMessage.decode(line: Data("{nope\n".utf8))
        }
    }

    @Test func socketURLIsInsideEasyNotchFolder() {
        let url = ClaudeBridgeMessage.socketURL(appSupport: URL(fileURLWithPath: "/tmp/x"))
        #expect(url.path == "/tmp/x/EasyNotch/claude.sock")
    }
}
