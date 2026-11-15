import Foundation
import Testing
@testable import EasyNotch

struct ClaudeHookTranslatorTests {
    func input(_ json: String) -> Data { Data(json.utf8) }

    @Test func bashRequestUsesCommand() throws {
        let data = input(#"{"tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/Users/a/EasyNotch","transcript_path":"/secret"}"#)
        let message = ClaudeHookTranslator.request(fromHookInput: data)
        #expect(message == .permissionRequest(tool: "Bash", summary: "npm test", project: "EasyNotch"))
        let encoded = try #require(message).encodeLine()
        #expect(!String(decoding: encoded, as: UTF8.self).contains("secret"))
    }

    @Test(arguments: ["Edit", "Write", "MultiEdit", "NotebookEdit"])
    func editRequestUsesFilePath(tool: String) {
        let data = input(#"{"tool_name":"\#(tool)","tool_input":{"file_path":"/p/App.swift"},"cwd":"/x/Proj"}"#)
        #expect(ClaudeHookTranslator.request(fromHookInput: data)
            == .permissionRequest(tool: tool, summary: "/p/App.swift", project: "Proj"))
    }

    @Test func notebookEditFallsBackToNotebookPath() {
        let data = input(#"{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/p/n.ipynb"},"cwd":"/x/Proj"}"#)
        #expect(ClaudeHookTranslator.request(fromHookInput: data)
            == .permissionRequest(tool: "NotebookEdit", summary: "/p/n.ipynb", project: "Proj"))
    }

    @Test func otherToolUsesToolName() {
        let data = input(#"{"tool_name":"WebFetch","tool_input":{"url":"https://x"},"cwd":"/x/Proj"}"#)
        #expect(ClaudeHookTranslator.request(fromHookInput: data)
            == .permissionRequest(tool: "WebFetch", summary: "WebFetch", project: "Proj"))
    }

    @Test func questionsAndPlansPassThrough() {
        for tool in ["AskUserQuestion", "ExitPlanMode"] {
            let data = input(#"{"tool_name":"\#(tool)","tool_input":{},"cwd":"/x/Proj"}"#)
            #expect(ClaudeHookTranslator.request(fromHookInput: data) == nil)
        }
        #expect(ClaudeHookTranslator.request(fromHookInput: input("not json")) == nil)
    }

    @Test func longSummaryIsCut() throws {
        let command = String(repeating: "a", count: 10_000)
        let data = input(#"{"tool_name":"Bash","tool_input":{"command":"\#(command)"},"cwd":"/x/Proj"}"#)
        let message = try #require(ClaudeHookTranslator.request(fromHookInput: data))
        guard case .permissionRequest(_, let summary, _) = message else {
            Issue.record("wrong case"); return
        }
        #expect(summary.utf8.count <= 4096)
        #expect(summary.hasSuffix("…"))
    }

    func decodeOutput(_ data: Data) throws -> (event: String?, behavior: String?, message: String?) {
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let out = root["hookSpecificOutput"] as? [String: Any]
        let decision = out?["decision"] as? [String: Any]
        return (out?["hookEventName"] as? String, decision?["behavior"] as? String, decision?["message"] as? String)
    }

    @Test func hookOutputAllow() throws {
        let out = try decodeOutput(ClaudeHookTranslator.hookOutput(allow: true))
        #expect(out.event == "PermissionRequest")
        #expect(out.behavior == "allow")
    }

    @Test func hookOutputDeny() throws {
        let out = try decodeOutput(ClaudeHookTranslator.hookOutput(allow: false))
        #expect(out.event == "PermissionRequest")
        #expect(out.behavior == "deny")
        #expect(out.message == "Denied from EasyNotch.")
    }

    @Test func hookOutputDenyCarriesTrimmedNote() throws {
        let out = try decodeOutput(ClaudeHookTranslator.hookOutput(allow: false, note: "  use git mv instead\n"))
        #expect(out.behavior == "deny")
        #expect(out.message == "use git mv instead")
        let blank = try decodeOutput(ClaudeHookTranslator.hookOutput(allow: false, note: "   "))
        #expect(blank.message == "Denied from EasyNotch.")
    }

    @Test func finishedKeepsTheEndOfTheMessageAndTheProject() throws {
        let long = String(repeating: "a", count: 700) + " Want me to commit?"
        let data = try JSONSerialization.data(withJSONObject: [
            "last_assistant_message": long, "cwd": "/Users/a/EasyNotch", "transcript_path": "/secret",
        ])
        guard case .finished(let message, let project)? = ClaudeHookTranslator.finished(fromHookInput: data) else {
            Issue.record("not a finished message"); return
        }
        #expect(message.hasPrefix("…") && message.hasSuffix("Want me to commit?"))
        #expect(message.count == 601)
        #expect(project == "EasyNotch")
        #expect(ClaudeHookTranslator.finished(fromHookInput: input(#"{"last_assistant_message":"  "}"#)) == nil)
    }

    @Test func stopOutputBlocksWithTheReplyOnlyWhenThereIsOne() throws {
        let data = try #require(ClaudeHookTranslator.stopOutput(reply: "  run the tests\n"))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["decision"] as? String == "block")
        #expect(root["reason"] as? String == "run the tests")
        #expect(ClaudeHookTranslator.stopOutput(reply: "   ") == nil)
        #expect(ClaudeHookTranslator.stopOutput(reply: nil) == nil)
    }

    @Test func usageReadsBothWindows() throws {
        let data = input(#"{"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1700000000}}}"#)
        let message = try #require(ClaudeHookTranslator.usage(fromStatusLine: data))
        #expect(message == .usage(
            fiveHour: UsageWindow(usedPercentage: 42, resetsAt: Date(timeIntervalSince1970: 1_700_000_000)),
            sevenDay: nil))
        #expect(ClaudeHookTranslator.usage(fromStatusLine: input(#"{"model":"x"}"#)) == nil)
    }
}
