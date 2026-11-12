import Foundation
import Testing
@testable import EasyNotch

struct ClaudeSetupTests {
    static let helper = "/Apps/Sean's Apps/EasyNotch.app/Contents/Helpers/easynotch-claude"
    static let otherHelper = "/Elsewhere/EasyNotch.app/Contents/Helpers/easynotch-claude"

    /// A fresh temp folder per test. Never touches ~/.claude.
    func makeFolder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "ClaudeSetupTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func setup(_ dir: URL, helper: String = helper) -> ClaudeSetup {
        ClaudeSetup(settingsURL: dir.appending(path: "settings.json"), helperPath: helper)
    }

    func write(_ json: String, to dir: URL, name: String = "settings.json") throws {
        try Data(json.utf8).write(to: dir.appending(path: name))
    }

    func read(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    var quotedHelper: String { ShellQuote.quote(Self.helper) }

    @Test func connectCreatesFileWhenMissing() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        #expect(s.status() == .disconnected)
        try s.connect()
        let json = try read(s.settingsURL)
        let expectedHooks: [String: Any] = [
            "PermissionRequest": [[
                "matcher": "*",
                "hooks": [["type": "command", "command": "\(quotedHelper) permission", "timeout": 86400]],
            ]],
        ]
        let expectedLine: [String: Any] = ["type": "command", "command": "\(quotedHelper) statusline"]
        #expect(NSDictionary(dictionary: json["hooks"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: expectedHooks))
        #expect(NSDictionary(dictionary: json["statusLine"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: expectedLine))
        #expect(s.status() == .connected)
    }

    @Test func connectKeepsOtherHooks() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        let original = #"{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo hi"}]}]},"model":"x"}"#
        try write(original, to: dir)
        try s.connect()
        let json = try read(s.settingsURL)
        let originalJSON = try JSONSerialization.jsonObject(with: Data(original.utf8)) as! [String: Any]
        let hooks = try #require(json["hooks"] as? [String: Any])
        #expect(NSArray(array: hooks["PreToolUse"] as? [Any] ?? [])
            == NSArray(array: (originalJSON["hooks"] as! [String: Any])["PreToolUse"] as! [Any]))
        #expect(json["model"] as? String == "x")
        #expect(hooks["PermissionRequest"] != nil)
    }

    @Test func connectKeepsOtherPermissionRequestGroups() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write(#"{"hooks":{"PermissionRequest":[{"matcher":"Bash","hooks":[{"type":"command","command":"mine"}]}]}}"#, to: dir)
        try s.connect()
        let hooks = try #require(try read(s.settingsURL)["hooks"] as? [String: Any])
        #expect((hooks["PermissionRequest"] as? [Any])?.count == 2)
        try s.disconnect()
        let after = try #require(try read(s.settingsURL)["hooks"] as? [String: Any])
        #expect((after["PermissionRequest"] as? [Any])?.count == 1)
    }

    @Test func connectWrapsExistingStatusLine() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write(#"{"statusLine":{"type":"command","command":"my-line","padding":2}}"#, to: dir)
        try s.connect()
        let line = try #require(try read(s.settingsURL)["statusLine"] as? [String: Any])
        #expect(line["command"] as? String == "\(quotedHelper) statusline --then 'my-line'")
        #expect(line["padding"] as? Int == 2)
        let sidecar = try read(dir.appending(path: "settings.json.easynotch-statusline"))
        #expect(NSDictionary(dictionary: sidecar)
            == ["type": "command", "command": "my-line", "padding": 2] as NSDictionary)
    }

    @Test func reconnectDoesNotDuplicate() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write(#"{"statusLine":{"type":"command","command":"my-line"}}"#, to: dir)
        try s.connect()
        try s.connect()
        let json = try read(s.settingsURL)
        let groups = try #require((json["hooks"] as? [String: Any])?["PermissionRequest"] as? [Any])
        #expect(groups.count == 1)
        let line = try #require(json["statusLine"] as? [String: Any])
        #expect(line["command"] as? String == "\(quotedHelper) statusline --then 'my-line'")
        try s.disconnect()
        let restored = try read(s.settingsURL)
        #expect((restored["statusLine"] as? [String: Any])?["command"] as? String == "my-line")
    }

    @Test func connectThenDisconnectRestoresOriginal() throws {
        let originals = [
            "{}",
            #"{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo hi"}]}]},"model":"x"}"#,
            #"{"statusLine":{"type":"command","command":"my-line","padding":2}}"#,
        ]
        for original in originals {
            let dir = try makeFolder()
            let s = setup(dir)
            try write(original, to: dir)
            try s.connect()
            try s.disconnect()
            let expected = try JSONSerialization.jsonObject(with: Data(original.utf8)) as! NSDictionary
            #expect(try read(s.settingsURL) as NSDictionary == expected)
            #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "settings.json.easynotch-statusline").path))
            #expect(s.status() == .disconnected)
        }
    }

    @Test func disconnectWithoutSidecarRemovesStatusLine() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try s.connect()
        try s.disconnect()
        #expect(try read(s.settingsURL)["statusLine"] == nil)
    }

    @Test func disconnectWithUnreadableSidecarRemovesLineAndKeepsSidecar() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write(#"{"statusLine":{"type":"command","command":"my-line"}}"#, to: dir)
        try s.connect()
        try write("{broken", to: dir, name: "settings.json.easynotch-statusline")
        try s.disconnect()
        #expect(try read(s.settingsURL)["statusLine"] == nil)
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "settings.json.easynotch-statusline").path))
    }

    @Test func invalidJSONIsRefusedAndUntouched() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write("{oops", to: dir)
        #expect(throws: ClaudeSetup.SetupError.unreadableSettings) { try s.connect() }
        #expect(throws: ClaudeSetup.SetupError.unreadableSettings) { try s.disconnect() }
        #expect(try Data(contentsOf: s.settingsURL) == Data("{oops".utf8))
        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "settings.json.easynotch-backup").path))
    }

    @Test func nonObjectJSONIsRefused() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        try write("[1,2]", to: dir)
        #expect(throws: ClaudeSetup.SetupError.unreadableSettings) { try s.connect() }
        #expect(try Data(contentsOf: s.settingsURL) == Data("[1,2]".utf8))
    }

    @Test func backupIsWritten() throws {
        let dir = try makeFolder()
        let s = setup(dir)
        let original = "{ \"model\" :   \"x\" }\n"
        try write(original, to: dir)
        try s.connect()
        #expect(try Data(contentsOf: dir.appending(path: "settings.json.easynotch-backup")) == Data(original.utf8))
    }

    @Test func movedAppNeedsReconnect() throws {
        let dir = try makeFolder()
        try setup(dir).connect()
        #expect(setup(dir, helper: Self.otherHelper).status() == .needsReconnect)
        // Reconnecting from the new path replaces the old entries.
        let moved = setup(dir, helper: Self.otherHelper)
        try moved.connect()
        #expect(moved.status() == .connected)
        let groups = try #require((try read(moved.settingsURL)["hooks"] as? [String: Any])?["PermissionRequest"] as? [Any])
        #expect(groups.count == 1)
    }

    @Test func symlinkedSettingsStayALink() throws {
        let dir = try makeFolder()
        let real = dir.appending(path: "real.json")
        try Data(#"{"model":"x"}"#.utf8).write(to: real)
        let link = dir.appending(path: "settings.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let s = ClaudeSetup(settingsURL: link, helperPath: Self.helper)
        try s.connect()
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil)
        let json = try read(real)
        #expect(json["model"] as? String == "x")
        #expect(json["hooks"] != nil)
    }
}
