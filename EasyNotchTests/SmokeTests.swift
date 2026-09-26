import Foundation
import Testing
@testable import EasyNotch

/// Proves the test setup works: tests run inside the app, so `Bundle.main` is EasyNotch.
struct SmokeTests {
    @Test func appVersionComesFromProjectSettings() {
        #expect(Bundle.main.appVersion == "1.1.0")
    }

    @Test func bundleIdentifierMatchesBlueprint() {
        #expect(Bundle.main.bundleIdentifier == "com.seanl.easynotch")
    }
}
