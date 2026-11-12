import Foundation

// easynotch-claude: run by Claude Code as a PermissionRequest hook ("permission") and as its
// status line ("statusline [--then <command>]"). It talks to the EasyNotch app over a Unix
// socket. Whatever goes wrong (app not running, bad input), it exits 0 with no output, so
// Claude Code falls back to its normal behavior.

/// `$HOME/Library/Application Support`. Uses the HOME variable (not FileManager) so tests can
/// point the helper at a temporary folder. For the unsandboxed app this is the same folder.
func applicationSupportURL() -> URL {
    let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    return URL(fileURLWithPath: home, isDirectory: true)
        .appendingPathComponent("Library/Application Support", isDirectory: true)
}

let socketURL = ClaudeBridgeMessage.socketURL(appSupport: applicationSupportURL())
let arguments = Array(CommandLine.arguments.dropFirst())
let input = FileHandle.standardInput.readDataToEndOfFile()

switch arguments.first {
case "permission":
    if let request = ClaudeHookTranslator.request(fromHookInput: input),
       case .decision(let allow)? = ClaudeBridgeClient.ask(request, to: socketURL),
       allow {
        FileHandle.standardOutput.write(ClaudeHookTranslator.hookOutput(allow: true))
    }

case "statusline":
    if let usage = ClaudeHookTranslator.usage(fromStatusLine: input) {
        _ = ClaudeBridgeClient.send(usage, to: socketURL)
    }
    // Keep the user's original status line working: run it with the same input.
    if arguments.count >= 3, arguments[1] == "--then" {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", arguments[2]]
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardOutput = FileHandle.standardOutput  // its output is ours
        if (try? process.run()) != nil {
            try? stdin.fileHandleForWriting.write(contentsOf: input)
            try? stdin.fileHandleForWriting.close()
            process.waitUntilExit()
        }
    }

default:
    break
}
exit(0)
