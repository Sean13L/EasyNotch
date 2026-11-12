import Foundation

/// Adds EasyNotch's permission hook and status line to Claude Code's settings file, and
/// removes exactly those again. It never touches anything else in the file.
///
/// Our entries are recognised by a command containing `easynotch-claude`. The file is
/// rewritten with sorted keys, so key order and spacing may change.
struct ClaudeSetup {
    enum Status: Equatable { case disconnected, connected, needsReconnect }
    enum SetupError: Error, Equatable { case unreadableSettings }

    let settingsURL: URL
    let helperPath: String

    // Claude Code's docs name no maximum for a hook's `timeout` (the default is 10 minutes),
    // so 86400 s (24 h) stands in for "wait indefinitely".
    private static let hookTimeoutSeconds = 86400
    private static let marker = "easynotch-claude"

    private var backupURL: URL { sibling("settings.json.easynotch-backup") }
    private var sidecarURL: URL { sibling("settings.json.easynotch-statusline") }

    private func sibling(_ name: String) -> URL {
        settingsURL.deletingLastPathComponent().appending(path: name)
    }

    static func live() -> ClaudeSetup {
        ClaudeSetup(
            settingsURL: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".claude/settings.json"),
            helperPath: Bundle.main.bundleURL
                .appending(path: "Contents/Helpers/easynotch-claude").path)
    }

    /// True when macOS is running the app from a random read-only copy (App Translocation),
    /// which happens to an unnotarized app opened straight from Downloads. A hook pointing
    /// there breaks as soon as the app quits, so connecting must wait until it's moved.
    static func isTranslocated(bundlePath: String) -> Bool {
        bundlePath.contains("/AppTranslocation/")
    }

    // MARK: Status

    private func writeBackup(_ data: Data) throws {
        try data.write(to: backupURL, options: .atomic)
        // Settings can hold API keys, so the backup gets the same permissions.
        let target = settingsURL.resolvingSymlinksInPath()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: target.path),
           let perms = attrs[.posixPermissions] {
            try FileManager.default.setAttributes([.posixPermissions: perms], ofItemAtPath: backupURL.path)
        }
    }

    private func hasOurEntries(_ root: [String: Any]) -> Bool {
        !ourCommands(in: root).isEmpty
    }

    private func ourCommands(in root: [String: Any]) -> [String] {
        var commands: [String] = []
        if let hooks = root["hooks"] as? [String: Any] {
            for case let groups as [Any] in hooks.values {
                for case let group as [String: Any] in groups {
                    for case let handler as [String: Any] in group["hooks"] as? [Any] ?? [] {
                        if let c = handler["command"] as? String { commands.append(c) }
                    }
                }
            }
        }
        if let c = (root["statusLine"] as? [String: Any])?["command"] as? String { commands.append(c) }
        return commands.filter { $0.contains(Self.marker) }
    }

    func status() -> Status {
        guard let root = try? load().root else { return .disconnected }
        let ours = ourCommands(in: root)
        if ours.isEmpty { return .disconnected }
        // Commands hold the shell-quoted path, so an apostrophe in it appears as '\''.
        let quoted = ShellQuote.quote(helperPath)
        return ours.contains { $0.contains(quoted) } ? .connected : .needsReconnect
    }

    // MARK: Connect

    func connect() throws {
        let (root, original) = try load()
        var root2 = root
        var hooks = try hooksDictionary(root2)
        stripOurHandlers(from: &hooks)

        var groups = hooks["PermissionRequest"] as? [Any] ?? []
        let command = "\(ShellQuote.quote(helperPath)) permission"
        groups.append([
            "matcher": "*",
            "hooks": [["type": "command", "command": command, "timeout": Self.hookTimeoutSeconds]],
        ] as [String: Any])
        hooks["PermissionRequest"] = groups
        root2["hooks"] = hooks

        // Status line. `original` is what the owner had before us (nil if nothing).
        let ours = "\(ShellQuote.quote(helperPath)) statusline"
        var line = root2["statusLine"] as? [String: Any]
        let hadNoStatusLine = line == nil
        var sidecarToWrite: [String: Any]?
        var wrapped: String?
        if let current = line, !isOurs(current) {
            sidecarToWrite = current
            wrapped = current["command"] as? String
        } else if line != nil, let saved = readSidecar() {
            wrapped = saved["command"] as? String // Reconnect keeps wrapping the same original.
        }
        if line == nil { line = ["type": "command"] }
        line?["type"] = "command"
        line?["command"] = wrapped.map { "\(ours) --then \(ShellQuote.quote($0))" } ?? ours
        root2["statusLine"] = line

        // Write order: backup, sidecar, then the settings file itself.
        // Back up only a file with none of our entries; on Reconnect the existing backup
        // is the owner's untouched copy and must stay.
        if let original, !hasOurEntries(root) { try writeBackup(original) }
        if hadNoStatusLine { try? FileManager.default.removeItem(at: sidecarURL) } // stale sidecar
        if let sidecarToWrite { try writeJSON(sidecarToWrite, to: sidecarURL) }
        try writeJSON(root2, to: settingsURL.resolvingSymlinksInPath())
    }

    // MARK: Disconnect

    func disconnect() throws {
        let (root, original) = try load()
        guard original != nil else { return }
        var root2 = root

        if var hooks = root2["hooks"] as? [String: Any] {
            let changed = stripOurHandlers(from: &hooks)
            if changed {
                if hooks.isEmpty { root2.removeValue(forKey: "hooks") } else { root2["hooks"] = hooks }
            }
        }

        var removeSidecar = false
        if let line = root2["statusLine"] as? [String: Any], isOurs(line) {
            if FileManager.default.fileExists(atPath: sidecarURL.path) {
                if let saved = readSidecar() {
                    root2["statusLine"] = saved
                    removeSidecar = true
                } else {
                    // Unreadable sidecar: drop our line and keep the file for the owner.
                    root2.removeValue(forKey: "statusLine")
                }
            } else {
                root2.removeValue(forKey: "statusLine")
            }
        }

        try writeJSON(root2, to: settingsURL.resolvingSymlinksInPath())
        if removeSidecar { try? FileManager.default.removeItem(at: sidecarURL) }
    }

    // MARK: Helpers

    /// Reads the settings file. A missing file is `{}` with no original bytes. A file that
    /// isn't a JSON object throws, and nothing is changed.
    private func load() throws -> (root: [String: Any], original: Data?) {
        let target = settingsURL.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: target.path) else { return ([:], nil) }
        guard let data = try? Data(contentsOf: target),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { throw SetupError.unreadableSettings }
        return (root, data)
    }

    /// `hooks` must be an object if present; anything else is treated as unreadable.
    private func hooksDictionary(_ root: [String: Any]) throws -> [String: Any] {
        guard let value = root["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else { throw SetupError.unreadableSettings }
        return hooks
    }

    private func isOurs(_ statusLine: [String: Any]) -> Bool {
        (statusLine["command"] as? String)?.contains(Self.marker) == true
    }

    private func readSidecar() -> [String: Any]? {
        guard let data = try? Data(contentsOf: sidecarURL) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Removes our handlers from every event, then drops groups and events left empty by
    /// that removal. Returns whether anything was removed.
    @discardableResult
    private func stripOurHandlers(from hooks: inout [String: Any]) -> Bool {
        var changed = false
        for (event, value) in hooks {
            guard let groups = value as? [Any] else { continue }
            var keptGroups: [Any] = []
            var eventChanged = false
            for group in groups {
                guard var g = group as? [String: Any], let handlers = g["hooks"] as? [Any] else {
                    keptGroups.append(group)
                    continue
                }
                let kept = handlers.filter { handler in
                    let command = (handler as? [String: Any])?["command"] as? String
                    return command?.contains(Self.marker) != true
                }
                if kept.count == handlers.count { keptGroups.append(group); continue }
                changed = true
                eventChanged = true
                if kept.isEmpty { continue }
                g["hooks"] = kept
                keptGroups.append(g)
            }
            if eventChanged {
                if keptGroups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = keptGroups }
            }
        }
        return changed
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
