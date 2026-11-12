import Foundation
import Testing
@testable import EasyNotch

struct ShellQuoteTests {
    @Test func quoteHandlesSpacesAndApostrophes() throws {
        #expect(ShellQuote.quote("a b'c") == "'a b'\\''c'")

        let original = "/Apps/Sean's Apps/x y"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf %s " + ShellQuote.quote(original)]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(String(decoding: data, as: UTF8.self) == original)
    }
}
