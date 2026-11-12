import Foundation

// Foundation only (see ClaudeBridgeMessage.swift): also compiled into the helper tool.

/// Turns Claude Code's hook and status line JSON into bridge messages, and back.
nonisolated enum ClaudeHookTranslator {
    /// Tools that Claude must ask about in the terminal itself, so we never intercept them.
    private static let passThroughTools: Set<String> = ["AskUserQuestion", "ExitPlanMode"]
    private static let fileTools: Set<String> = ["Edit", "Write", "MultiEdit", "NotebookEdit"]

    /// Reads a PermissionRequest hook's stdin. Only the tool name, a short summary and the
    /// project folder name are kept; everything else (transcript path, full input) is dropped.
    static func request(fromHookInput data: Data) -> ClaudeBridgeMessage? {
        // JSONSerialization because the shape of `tool_input` differs for every tool.
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = root["tool_name"] as? String,
              !passThroughTools.contains(tool) else { return nil }
        let input = root["tool_input"] as? [String: Any] ?? [:]

        var summary = tool
        if tool == "Bash", let command = input["command"] as? String {
            summary = command
        } else if fileTools.contains(tool),
                  let path = (input["file_path"] as? String) ?? (input["notebook_path"] as? String) {
            summary = path
        }

        let cwd = root["cwd"] as? String ?? ""
        let project = (cwd as NSString).lastPathComponent
        return .permissionRequest(
            tool: tool, summary: cut(summary, toBytes: ClaudeBridgeMessage.maxSummaryBytes), project: project)
    }

    /// The JSON Claude Code expects on stdout for a PermissionRequest hook.
    static func hookOutput(allow: Bool) -> Data {
        var decision: [String: Any] = ["behavior": allow ? "allow" : "deny"]
        if !allow { decision["message"] = "Denied from EasyNotch." }
        let root: [String: Any] = [
            "hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]
        ]
        return (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
    }

    /// Reads the status line JSON. Nil when it has no `rate_limits` (e.g. API-key users).
    static func usage(fromStatusLine data: Data) -> ClaudeBridgeMessage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any] else { return nil }
        return .usage(fiveHour: window(limits["five_hour"]), sevenDay: window(limits["seven_day"]))
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let used = (dict["used_percentage"] as? NSNumber)?.doubleValue,
              let resets = (dict["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return UsageWindow(usedPercentage: used, resetsAt: Date(timeIntervalSince1970: resets))
    }

    /// Cuts to at most `limit` UTF-8 bytes, ending in "…". Cuts between Characters so an
    /// emoji is never split.
    private static func cut(_ text: String, toBytes limit: Int) -> String {
        guard text.utf8.count > limit else { return text }
        let ellipsis = "…"
        var budget = limit - ellipsis.utf8.count
        var result = ""
        for character in text {
            let size = String(character).utf8.count
            if size > budget { break }
            result.append(character)
            budget -= size
        }
        return result + ellipsis
    }
}
