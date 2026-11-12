# Claude Code in the Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Answer Claude Code CLI permission requests from the notch, and show the 5-hour and weekly usage limits.

**Architecture:** A bundled command-line helper (`easynotch-claude`) is run by Claude Code as a
`PermissionRequest` hook and as the status line command. It talks to EasyNotch over a Unix socket
that only the owner can open. In the app, `ClaudeService` keeps a first-in, first-out queue of
waiting requests, plus the latest usage. These show up as a wing alert and a new Claude tab.
`ClaudeSetup` adds the entries to `~/.claude/settings.json` and removes them again.

**Tech Stack:** Swift 6, SwiftUI, Foundation and POSIX sockets with GCD read sources, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-11-claude-code-notch-design.md`. Read it first. The
three places where this plan differs from it are listed below.

### Where the plan differs from the spec (and why)
1. **Tab visibility uses the existing `hiddenModules` list** (Modules pane), not a new
   `showClaudeTab` bool. Every other tab already works this way, so adding `.claude` to
   `NotchModule` is all that's needed. No new `AppSettings` keys are added.
2. **The original status line is saved in a sidecar file**
   (`~/.claude/settings.json.easynotch-statusline`, holding the whole original JSON object),
   not in `AppSettings`. This keeps fields like `padding`, means `ClaudeSetup` can be tested
   with nothing but temporary folders, and survives reinstalling EasyNotch.
3. **`ClaudeBridgeServer` is a `final class` that runs on its own private serial `DispatchQueue`**,
   not an `actor`. GCD read sources deliver events on a queue, and pairing that with an actor
   would need a custom executor. The spec's actual goal is still met: the main thread is never
   blocked.

## Global Constraints
- macOS 14+, Swift 6, default MainActor isolation. Types in `Shared/` that the helper uses must be `nonisolated`.
- No third-party packages. Hand-edit `project.yml` only, then run `xcodegen generate`. Never edit `EasyNotch.xcodeproj`.
- Socket path: `~/Library/Application Support/EasyNotch/claude.sock`. Folder `0700`, socket `0600`. Remove any leftover socket at start.
- Each message is one line of JSON ending in `\n`, at most `64 * 1024` bytes. Summaries are cut to 4096 bytes.
- The helper sends only `tool`, `summary`, and `project` (the last path component of `cwd`).
- Hook entry: `{"matcher":"*","hooks":[{"type":"command","command":"'<helper>' permission","timeout":86400}]}` under `hooks.PermissionRequest`.
- Deny message text: `Denied from EasyNotch.`
- `AskUserQuestion` and `ExitPlanMode` → the helper exits 0 with no output.
- Backup file: `settings.json.easynotch-backup`. Write with `.prettyPrinted`, `.sortedKeys`, atomically.
- Icon: the SF Symbol `terminal` everywhere. Never the Claude logo.
- Logging: `Log.claude`. Log the tool name and connection events only, never the summary. Never use `print` in the app (the helper writes its hook output to stdout, which is its job).
- Idle CPU stays near 0: no timers or polling. The "Updated N min ago" text uses `TimelineView` only while it's visible.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
- Ask the owner before each commit (project rule). The commit steps below say "commit" for brevity.

## Review Focus
1. **The Claude tab is hidden in Modules while a request arrives.** Nobody could answer it, so the
   service should close the connection straight away and the terminal prompt appears. Test in Task 5.
2. **Pressing Return twice quickly.** Answering request 1 must not also answer request 2, which
   moves to the front at that moment. A new front request ignores answers for 0.5 s. Test in Task 5.
3. **`~/.claude/settings.json` is a symlink** (common with dotfiles setups). Connect and Disconnect
   must write to the file the link points to, not replace the link with a plain file. Test in Task 4.
4. **EasyNotch is in a folder whose name contains a space or an apostrophe** (for example
   `Sean's Apps`). The hook command must still run. Test `ShellQuote` in Task 4.
5. **A wrapped status line while EasyNotch isn't running.** The original status line must still
   print, and quickly. Test in Task 3.

---

## File structure

| File | Responsibility |
|---|---|
| `EasyNotch/Shared/ClaudeBridgeMessage.swift` | The message types sent over the socket, line encoding and decoding, limits, socket path |
| `EasyNotch/Shared/ClaudeHookTranslator.swift` | Hook stdin JSON → request message, decision → hook stdout JSON, status line JSON → usage message |
| `EasyNotch/Shared/ClaudeBridgeClient.swift` | Socket client: connect, send a line, optionally wait for one reply line |
| `EasyNotch/Shared/ShellQuote.swift` | Single-quote shell escaping |
| `EasyNotch/Features/Claude/ClaudeBridgeServer.swift` | Listening socket, one `Connection` per peer, hangup callbacks |
| `EasyNotch/Features/Claude/ClaudeService.swift` | `@Observable` queue, usage, alert state, allow and deny |
| `EasyNotch/Features/Claude/ClaudeSetup.swift` | Connect, disconnect, and status for `settings.json` |
| `EasyNotch/Features/Claude/ClaudeView.swift` | The Claude tab |
| `EasyNotch/Features/Claude/ClaudeCompactView.swift` | Wings |
| `EasyNotch/Features/Claude/ClaudeUsageView.swift` | The two usage bars and the "Updated…" line |
| `EasyNotch/Settings/Panes/ClaudePane.swift` | Settings pane |
| `EasyNotchHelper/main.swift` | Helper entry point: parses `permission` / `statusline [--then cmd]` |
| `EasyNotchTests/Claude*Tests.swift`, `ShellQuoteTests.swift` | Tests per type |

---

### Task 1: Message types and hook translation

**Files:**
- Create: `EasyNotch/Shared/ClaudeBridgeMessage.swift`, `EasyNotch/Shared/ClaudeHookTranslator.swift`
- Test: `EasyNotchTests/ClaudeBridgeMessageTests.swift`, `EasyNotchTests/ClaudeHookTranslatorTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated enum ClaudeBridgeMessage: Codable, Equatable, Sendable` with these cases:
    - `permissionRequest(tool: String, summary: String, project: String)`
    - `usage(fiveHour: UsageWindow?, sevenDay: UsageWindow?)`
    - `decision(allow: Bool)`
  - `nonisolated struct UsageWindow: Codable, Equatable, Sendable { var usedPercentage: Double; var resetsAt: Date }`
  - `ClaudeBridgeMessage.encodeLine() throws -> Data`. The result ends in `\n`, and dates are seconds since 1970.
  - `static ClaudeBridgeMessage.decode(line: Data) throws -> ClaudeBridgeMessage`. Throws `ClaudeBridgeError.tooLong` when the line is over `maxLineBytes`, and `.invalid` when it can't be decoded.
  - `static let maxLineBytes = 65_536`, `static let maxSummaryBytes = 4_096`
  - `static func socketURL(appSupport: URL) -> URL`
  - `nonisolated enum ClaudeHookTranslator` with:
    - `static func request(fromHookInput: Data) -> ClaudeBridgeMessage?`. Returns nil for AskUserQuestion, ExitPlanMode, or JSON it can't read.
    - `static func hookOutput(allow: Bool) -> Data`
    - `static func usage(fromStatusLine: Data) -> ClaudeBridgeMessage?`. Returns nil when there's no `rate_limits`.

- [ ] **Step 1: Write the failing tests**
  - `messagesRoundTripThroughOneLine`: each case encodes to data whose last byte is `0x0A` and that contains exactly one `\n`, including a summary of `"echo a\necho b"`. Decoding it gives back an equal value.
  - `oversizedLineIsRejected`: a line of 65_537 bytes throws `.tooLong`. `garbageIsRejected`: `"{nope\n"` throws `.invalid`.
  - `socketURLIsInsideEasyNotchFolder`: `socketURL(appSupport: /tmp/x)` → `/tmp/x/EasyNotch/claude.sock`.
  - `bashRequestUsesCommand`: input `{"tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/Users/a/EasyNotch","transcript_path":"/secret"}` → `.permissionRequest(tool:"Bash", summary:"npm test", project:"EasyNotch")`. The encoded data must not contain `"secret"`.
  - `editRequestUsesFilePath`: for each of Edit, Write, MultiEdit, NotebookEdit with `file_path: "/p/App.swift"` → summary `/p/App.swift`. NotebookEdit uses `notebook_path` when `file_path` is missing.
  - `otherToolUsesToolName`: `WebFetch` → summary `WebFetch`.
  - `questionsAndPlansPassThrough`: `AskUserQuestion` and `ExitPlanMode` → nil.
  - `longSummaryIsCut`: a 10_000-byte command → summary `.utf8.count <= 4096`, ending in `…`.
  - `hookOutputAllow` and `hookOutputDeny`: decode the output and check that `hookSpecificOutput.hookEventName == "PermissionRequest"` and `decision.behavior` is `allow` or `deny`. For deny, also check `decision.message == "Denied from EasyNotch."`.
  - `usageReadsBothWindows`: `{"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1700000000}}}` → `fiveHour == UsageWindow(42, Date(timeIntervalSince1970:1700000000))`, `sevenDay == nil`. No `rate_limits` → nil.

- [ ] **Step 2: Run them and confirm they fail**
  Run: `xcodegen generate && xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -derivedDataPath build test -only-testing:EasyNotchTests/ClaudeBridgeMessageTests -only-testing:EasyNotchTests/ClaudeHookTranslatorTests`
  Expected: build failure (the types don't exist yet).

- [ ] **Step 3: Implement both files.** Cut the summary on a `Character` boundary so a cut never splits an emoji. Use `JSONSerialization` to read hook input, because the shape of `tool_input` varies by tool.

- [ ] **Step 4: Run the tests and confirm they pass.** Same command. Expected: all pass.

- [ ] **Step 5: Commit.** `git commit -m "Add Claude bridge message types and hook translation"`

---

### Task 2: Socket server and client

**Files:**
- Create: `EasyNotch/Shared/ClaudeBridgeClient.swift`, `EasyNotch/Features/Claude/ClaudeBridgeServer.swift`
- Modify: `EasyNotch/Shared/Log.swift` (add `static let claude = Logger(subsystem: subsystem, category: "claude")`)
- Test: `EasyNotchTests/ClaudeBridgeRoundTripTests.swift`

**Interfaces:**
- Consumes: `ClaudeBridgeMessage` (Task 1).
- Produces:
  - `nonisolated enum ClaudeBridgeClient`:
    - `static func send(_ message: ClaudeBridgeMessage, to socket: URL) -> Bool`. Doesn't wait for a reply, and returns false if it can't connect.
    - `static func ask(_ message: ClaudeBridgeMessage, to socket: URL) -> ClaudeBridgeMessage?`. Blocks until there's one reply line. Returns nil if it can't connect, the connection closes, or the reply is invalid.
  - `nonisolated final class ClaudeBridgeServer: @unchecked Sendable`, which has:
    - `init(socketURL: URL)`
    - `func start() throws`
    - `func stop()`
    - `var onMessage: @Sendable (ClaudeBridgeMessage, Connection) -> Void`
    - `var onHangup: @Sendable (Connection.ID) -> Void`
  - `nonisolated final class Connection: Identifiable, @unchecked Sendable`, which has:
    - `let id: UUID`
    - `func reply(_ message: ClaudeBridgeMessage)`, which writes the line and then closes the connection
    - `func close()`
  - Callbacks run on the server's queue. `ClaudeService` (Task 5) moves to the main actor itself.

- [ ] **Step 1: Write the failing tests.** Every test uses a socket in a short temporary folder (`/tmp/en-<6 random chars>/s.sock`), because Unix socket paths are limited to 104 bytes.
  - `askGetsTheServersReply`: `onMessage` replies `.decision(allow: true)` → `ask(.permissionRequest…)` returns `.decision(allow: true)`.
  - `askReturnsNilWithoutServer`: no server → nil, in under 1 s.
  - `serverStoppingMidRequestReturnsNil`: `onMessage` calls `server.stop()` → `ask` returns nil.
  - `clientHangupIsReported`: send a request without waiting for a reply and close the client → `onHangup` fires with that connection's id. Wait with a `confirmation` and a 2 s limit.
  - `oversizedLineClosesConnection`: write 70_000 bytes with no newline → the client sees the connection close, and `onMessage` is never called.
  - `startRemovesLeftoverSocketAndSetsPermissions`: create a plain file at the socket path, then `start()` → succeeds. The folder mode is `0o700` and the socket mode is `0o600`.

- [ ] **Step 2: Run them and confirm they fail.** Use `-only-testing:EasyNotchTests/ClaudeBridgeRoundTripTests`. Expected: build failure.

- [ ] **Step 3: Implement.** Server: `socket(AF_UNIX, SOCK_STREAM)`, `bind`, `chmod 0600`, `listen`,
  then a `DispatchSourceRead` on the listening socket. Each accepted connection gets its own
  read source on the same serial queue, which collects bytes until `\n`. A read of 0 bytes, or an
  error, means the peer hung up. Set `SO_NOSIGPIPE` on every socket, so writing to a closed peer
  can't crash the app. Client: blocking `connect` and `write`, then for `ask`, a blocking `read`
  until `\n` or end of stream. No timeout, because the hook's own `timeout` limits it.

- [ ] **Step 4: Run the tests and confirm they pass.** Expected: all pass. Also run the whole suite once to check nothing else broke.

- [ ] **Step 5: Commit.** `git commit -m "Add Claude bridge socket server and client"`

---

### Task 3: The `easynotch-claude` helper, bundled and signed

**Files:**
- Create: `EasyNotchHelper/main.swift`
- Modify: `project.yml`, `scripts/release.sh`
- Test: `EasyNotchTests/ClaudeHelperTests.swift` (runs the built helper as a process)

**Interfaces:**
- Consumes: `ClaudeHookTranslator`, `ClaudeBridgeClient`, `ClaudeBridgeMessage.socketURL` (Tasks 1–2).
- Produces: the executable at `EasyNotch.app/Contents/Helpers/easynotch-claude`, which takes these arguments:
  - `permission`
  - `statusline [--then <command>]`

  Its exit code is always 0.

- [ ] **Step 1: Update `project.yml`.**
  - Add a target `easynotch-claude` with:
    - `type: tool`, `platform: macOS`
    - sources: `EasyNotchHelper` plus these three files from `EasyNotch/Shared`:
      `ClaudeBridgeMessage.swift`, `ClaudeHookTranslator.swift`, `ClaudeBridgeClient.swift`
    - `ENABLE_HARDENED_RUNTIME: "YES"`
    - `PRODUCT_BUNDLE_IDENTIFIER: com.seanl.easynotch.claude`
  - Add it to the `EasyNotch` target's `dependencies` with
    `copy: {destination: wrapper, subpath: Contents/Helpers}` and `codeSign: true`.
  Check the dependency syntax for copying into the app with ctx7
  (`npx ctx7@latest library XcodeGen "dependency copy destination wrapper subpath"`) before
  building.

- [ ] **Step 2: Write `main.swift`.** It has three paths:
  - **`permission`:** read all of stdin. Use `ClaudeHookTranslator.request`, and if it returns
    nil, exit 0. Then call `ClaudeBridgeClient.ask`. If the reply is `.decision(allow)`, write
    `hookOutput(allow:)` to stdout. Exit 0 in every case.
  - **`statusline`:** read stdin. If `usage(fromStatusLine:)` returns a message, call `send` and
    ignore the result.
  - **`--then cmd`:** run `/bin/sh -c cmd` with `Process`, feed it the same stdin bytes, and
    copy its stdout to ours.

  The socket URL comes from
  `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]`.

- [ ] **Step 3: Write the failing tests.** These run `build/Build/Products/Debug/EasyNotch.app/Contents/Helpers/easynotch-claude` with `Process`:
  - `helperIsBundled`: the file exists and can be run.
  - `permissionWithoutAppPrintsNothing`: give it a Bash hook input on stdin, with `HOME` pointing
    at an empty temporary folder so no socket exists. Expect exit code 0, empty stdout, and that
    it finishes in under 2 s.
  - `askUserQuestionPrintsNothing`: same check, with `tool_name: AskUserQuestion`.
  - **Review Focus 5:** `statuslineThenRunsOriginalWithoutApp`: `statusline --then 'cat >/dev/null; echo hi'`
    with no app running → stdout `"hi\n"`, finishing in under 2 s.
  - `permissionGetsAllowFromServer`: start a `ClaudeBridgeServer` whose socket is under
    `<tmpHOME>/Library/Application Support/EasyNotch/claude.sock` and which answers allow. Run
    the helper with `HOME=<tmpHOME>`, and expect stdout to decode to `behavior == "allow"`.
    (Pass `HOME` explicitly, because `FileManager` reads it to find Application Support.)

- [ ] **Step 4: Build and run the tests.**
  Run: `xcodegen generate && xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Debug -derivedDataPath build build && xcodebuild ... test -only-testing:EasyNotchTests/ClaudeHelperTests`
  Expected: all pass. `ls build/Build/Products/Debug/EasyNotch.app/Contents/Helpers` shows `easynotch-claude`.

- [ ] **Step 5: Update `release.sh`.** Before the existing `codesign` of `$APP`, sign the helper:
  `codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP/Contents/Helpers/easynotch-claude"`.
  Code inside an app has to be signed before the app itself. The existing "Apple Development"
  grep already checks the helper too. Check the script with a dry run if it supports one;
  otherwise just read it through once more. Don't publish anything.

- [ ] **Step 6: Commit.** `git commit -m "Bundle the easynotch-claude helper"`

---

### Task 4: `ClaudeSetup`: connect, disconnect, status

**Files:**
- Create: `EasyNotch/Features/Claude/ClaudeSetup.swift`, `EasyNotch/Shared/ShellQuote.swift`
- Test: `EasyNotchTests/ClaudeSetupTests.swift`, `EasyNotchTests/ShellQuoteTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated enum ShellQuote { static func quote(_ s: String) -> String }`. Wraps the string in `'…'`, and writes each `'` as `'\''`.
  - `struct ClaudeSetup`, with:
    - `let settingsURL: URL`
    - `let helperPath: String`
  - `enum Status: Equatable { case disconnected, connected, needsReconnect }`
  - `enum SetupError: Error, Equatable { case unreadableSettings }`
  - methods:
    - `func status() -> Status`
    - `func connect() throws`
    - `func disconnect() throws`
  - `static func live() -> ClaudeSetup`, which uses `~/.claude/settings.json` and the bundled helper path
  - Our entries: any hook `command`, or `statusLine.command`, that contains `"easynotch-claude"`.
    `.connected` means one of our entries contains `helperPath`. `.needsReconnect` means our
    entries exist but none contains `helperPath`.

- [ ] **Step 0: Check the timeout value.** Run `npx ctx7@latest docs /websites/code_claude "hook timeout field maximum value"`. If the docs give a maximum below 86400, use that maximum. Write the result in a one-line comment next to the constant.

- [ ] **Step 1: Write the failing tests.** Each test uses its own temporary folder and the helper path `/Apps/Sean's Apps/EasyNotch.app/Contents/Helpers/easynotch-claude`.
  - `quoteHandlesSpacesAndApostrophes` **(Review Focus 4)**: `quote("a b'c")` → `'a b'\''c'`. Also,
    `/bin/sh -c "printf %s " + quote(x)` prints `x` exactly.
  - `connectCreatesFileWhenMissing`: no file → after connect, the file holds the hook group from
    Global Constraints, and `statusLine == {"type":"command","command":"<quoted> statusline"}`.
    `status() == .connected`.
  - `connectKeepsOtherHooks`: a file with `{"hooks":{"PreToolUse":[…]}, "model":"x"}` → both are
    unchanged after connect.
  - `connectWrapsExistingStatusLine`: `{"statusLine":{"type":"command","command":"my-line","padding":2}}`
    → the new command is `<quoted> statusline --then 'my-line'`, `padding` is still 2, and the
    sidecar holds the original object.
  - `reconnectDoesNotDuplicate`: calling connect twice → exactly one of our groups.
  - `connectThenDisconnectRestoresOriginal`: for each of the three files above, the parsed JSON
    after connect and then disconnect equals the original (compared as `NSDictionary`), and the
    sidecar is gone.
  - `invalidJSONIsRefusedAndUntouched`: the file contents `{oops` → `connect()` throws
    `.unreadableSettings`. The bytes are unchanged and no backup is created.
  - `backupIsWritten`: after connect, `settings.json.easynotch-backup` equals the original bytes.
  - `movedAppNeedsReconnect`: connect with path A, then check `status()` using path B → `.needsReconnect`.
  - `symlinkedSettingsStayALink` **(Review Focus 3)**: `settings.json` is a symlink to
    `real.json` → after connect, `settings.json` is still a symlink and `real.json` holds the new
    contents.

- [ ] **Step 2: Run them and confirm they fail.** Expected: build failure.

- [ ] **Step 3: Implement.**
  - Before any write, resolve the target with `URL.resolvingSymlinksInPath()`.
  - Read the file with `JSONSerialization` into `[String: Any]`.
  - Write with `[.prettyPrinted, .sortedKeys]` and `.atomic`.
  - Disconnect drops arrays and objects that become empty only if Connect created them, which
    keeps the "restores original" test exact: remove `hooks.PermissionRequest` if it's empty, and
    `hooks` if it's empty.
  - If there's no sidecar on Disconnect, remove `statusLine`.

- [ ] **Step 4: Run the tests and confirm they pass.**

- [ ] **Step 5: Commit.** `git commit -m "Add ClaudeSetup to connect EasyNotch to Claude Code"`

---

### Task 5: `ClaudeService` and app wiring

**Files:**
- Create: `EasyNotch/Features/Claude/ClaudeService.swift`
- Modify: `EasyNotch/App/AppServices.swift` (create it, `activate()` it, and acknowledge it in `onNotchOpened`)
- Test: `EasyNotchTests/ClaudeServiceTests.swift`

**Interfaces:**
- Consumes: `ClaudeBridgeServer`, `Connection`, `ClaudeBridgeMessage`, `ClaudeSetup` (Tasks 2 and 4).
- Produces:
  - `nonisolated protocol ClaudeConnection: AnyObject, Sendable { var id: UUID { get }; func reply(_: ClaudeBridgeMessage); func close() }`. `Connection` conforms, and tests use a fake.
  - `struct ClaudeRequest: Identifiable, Equatable`, with:
    - `let id: UUID` (the connection's id)
    - `tool`, `summary`, `project: String`
    - `let receivedAt: Date`
  - `struct ClaudeUsage: Equatable`, with:
    - `var fiveHour`, `var sevenDay: UsageWindow?`
    - `var updatedAt: Date`
  - `@Observable final class ClaudeService`, with:
    - `init(settings: AppSettings, now: @escaping () -> Date = Date.init)`
    - `private(set) var pending: [ClaudeRequest]`
    - `private(set) var usage: ClaudeUsage?`
    - `private(set) var setupStatus: ClaudeSetup.Status`
    - `var showsAlert: Bool`, which is true when `pending` is non-empty and the alert hasn't been acknowledged since the last new request
    - methods:
      - `func activate()`
      - `func acknowledgeAlerts()`
      - `func allow(_ id: UUID)` and `func deny(_ id: UUID)`
      - `func canAnswer(_ id: UUID) -> Bool`
      - `func connect() throws` and `func disconnect() throws`, which call `ClaudeSetup` then refresh `setupStatus`
    - for tests and the server:
      - `func receive(_ message: ClaudeBridgeMessage, from connection: ClaudeConnection)`
      - `func connectionClosed(_ id: UUID)`
  - `static let answerGuard: TimeInterval = 0.5`

- [ ] **Step 1: Write the failing tests** (using `withIsolatedDefaults`, a fake connection that records replies and closes, and an adjustable `now`):
  - `requestsQueueOldestFirst`: three requests → `pending.map(\.summary)` keeps their arrival order.
  - `allowRepliesToTheRightConnectionAndRemovesIt`: `allow(second.id)` → only the second fake received `.decision(allow: true)`, and `pending.count == 2`.
  - `denyRepliesFalse`: deny → `.decision(allow: false)`.
  - `hangupRemovesRequestWithoutReply`: `connectionClosed(id)` → removed, and nothing was sent.
  - `usageUpdatesTimestampAndKeepsMissingWindowMissing`: a usage message with only `sevenDay` → `usage?.fiveHour == nil`, and `updatedAt == now()`.
  - `alertClearsOnAcknowledgeAndReturnsOnNewRequest`: after acknowledging, `showsAlert` is false. A new request sets it back to true.
  - `hiddenTabClosesRequestsImmediately` **(Review Focus 1)**: with `settings.hiddenModules = ["claude"]`, a request → the fake is closed with no reply, and `pending` stays empty.
  - `newFrontRequestIgnoresQuickAnswers` **(Review Focus 2)**: two requests. Allow the first at `t0`. At `t0 + 0.2`, `canAnswer(second.id)` is false and `allow(second.id)` is a no-op. At `t0 + 0.6` it works.

- [ ] **Step 2: Run them and confirm they fail.**

- [ ] **Step 3: Implement.**
  - `activate()` refreshes `setupStatus` from `ClaudeSetup.live()`. If it's `.connected`, it starts
    `ClaudeBridgeServer(socketURL:)` with callbacks that call
    `Task { @MainActor in self.receive / connectionClosed }`.
  - `connect()` starts the server, and `disconnect()` stops it, which closes every pending
    connection so those requests fall back to the terminal.
  - Log with `Log.claude.info("request \(tool, privacy: .public)")` and never log the summary.
  - In `AppServices`:
    - add `let claude: ClaudeService` and call `claude.activate()` in `start()`
    - add `claude.acknowledgeAlerts()` to the `onNotchOpened` closure
    - pass `claude` into `NotchFeatures` (Task 6) and `SettingsWindowController` (Task 7)

- [ ] **Step 4: Run the tests and confirm they pass,** then run the whole suite.

- [ ] **Step 5: Commit.** `git commit -m "Add ClaudeService queue and usage"`

---

### Task 6: Notch UI: tab, wings, alert priority

**Files:**
- Modify:
  - `EasyNotch/Notch/NotchModule.swift` (`.claude`, title `"Claude"`, symbol `"terminal"`)
  - `EasyNotch/Notch/LiveActivity.swift`
  - `EasyNotch/Notch/Views/CompactView.swift`
  - `EasyNotch/Notch/Views/ExpandedView.swift`
  - `EasyNotch/Notch/NotchWindowController.swift` (`NotchFeatures.claude`, plus the environment injection beside the others)
  - `EasyNotch/App/AppServices.swift` (`liveActivityProvider`)
- Create: `EasyNotch/Features/Claude/ClaudeView.swift`, `ClaudeCompactView.swift`, `ClaudeUsageView.swift`
- Test: `EasyNotchTests/LiveActivityTests.swift` (create it unless `graphify query "LiveActivity resolve tests"` finds an existing file that tests `resolve`; if one does, add the tests there), plus `ModuleOrderTests`

**Interfaces:**
- Consumes: `ClaudeService.pending`, `usage`, `setupStatus`, `showsAlert`, `allow`, `deny`, `canAnswer` (Task 5).
- Produces:
  - `LiveActivity.claudeRequest`, with `module == .claude`
  - `Candidates.claudeWaiting: Bool`
  - `struct ClaudeCompactView: View { let side: Side }`
  - `struct ClaudeView: View`

- [ ] **Step 1: Write the failing tests.**
  - `claudeRequestBeatsOtherAlertsButNotPomodoroAlert`:
    - `claudeWaiting` + `chargingFlash` + `meetingSoon` + `lowBattery` → `.claudeRequest`
    - add `phaseEnded` → `.pomodoroAlert`
  - `claudeRequestOpensClaudeTab`: `LiveActivity.claudeRequest.module == .claude`.
  - `newModuleAppendsToSavedOrder`: `NotchModule.ordered(from: ["music","shelf","pomodoro","calendar","battery","system"]).last == .claude`. This already works through `ordered(from:)`; the test pins it in place.

- [ ] **Step 2: Run them and confirm they fail.**

- [ ] **Step 3: Implement.**
  - **`LiveActivity.resolve`:** right after the `phaseEnded` check, add
    `if candidates.claudeWaiting { return .claudeRequest }`. Update the doc comment's ordering list.
  - **`AppServices`:** set
    `claudeWaiting: visible.contains(.claude) && claude.showsAlert`.
  - **Wings:**
    - leading: `Image(systemName: "terminal")` and `pending.count`
    - trailing: the front request's summary, `.lineLimit(1)`, `.truncationMode(.middle)`
  - **`ClaudeView`:** follows spec §4.2–4.3.
    - **Header:** `"\(project) · \(tool)"` and `"1 of \(pending.count)"`.
    - **Summary:** in `.monospaced`, `.lineLimit(3)`, with `.help(summary)` and
      `.accessibilityLabel(summary)`.
    - **Buttons:** Deny (`.keyboardShortcut(.cancelAction)`) and Allow
      (`.keyboardShortcut(.defaultAction)`). Both are `.disabled(!claude.canAnswer(id))`.
      `canAnswer` depends on time, so wrap the buttons in `TimelineView(.periodic(from: .now, by: 0.25))`
      only while `!canAnswer`, which re-enables them without a background timer.
    - **States:**
      - not connected: an "Open Settings" button that uses the existing `onShowSettings` route
      - needs reconnect
      - no usage yet
  - **`ClaudeUsageView`:** two `ProgressView(value:total:100)` rows labelled `5h` and `Week`, with
    "resets in 2h 10m", or a weekday name when more than 24 h away (use `Date.FormatStyle`).
    "Updated N min ago" sits inside `TimelineView(.everyMinute)`. Tint with `NotchAccent`.
    Check that the label text contrast is at least 4.5:1 on black.

- [ ] **Step 4: Run the tests, then build and launch for a visual check.**
  - Run the whole suite. Expected: everything passes.
  - Then: `killall EasyNotch; open build/Build/Products/Debug/EasyNotch.app`.
  - Feed a fake request:

    ```
    echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/tmp/demo"}' | build/Build/Products/Debug/EasyNotch.app/Contents/Helpers/easynotch-claude permission
    ```

    (this needs Task 7's Connect, or a temporarily started server).
  - Expected:
    - the wings show `terminal 1 | npm test`
    - hovering shows the tab
    - Return prints the allow JSON in the terminal

- [ ] **Step 5: Commit.** `git commit -m "Show Claude Code requests and usage in the notch"`

---

### Task 7: Settings pane

**Files:**
- Create: `EasyNotch/Settings/Panes/ClaudePane.swift`
- Modify:
  - `EasyNotch/Settings/SettingsView.swift` (`SettingsPane.claude`, title `"Claude Code"`, icon `"terminal"`, routing)
  - `EasyNotch/Settings/SettingsWindowController.swift` (`init` takes `claude: ClaudeService`, which it injects)
- Test: none new. The pane is a thin view over `ClaudeService.connect` and `disconnect`, which Tasks 4–5 test.

**Interfaces:**
- Consumes: `ClaudeService.setupStatus`, `connect()`, `disconnect()` (Task 5).

- [ ] **Step 1: Build the pane** (spec §4.4):
  - **Status text:**
    - `.disconnected` → "Not connected"
    - `.connected` → "Connected"
    - `.needsReconnect` → "EasyNotch moved — reconnect"
  - **Button:** Connect, Disconnect, or Reconnect (Reconnect calls `connect()`).
  - **Error:** a thrown `.unreadableSettings` shows this text in red (with AA contrast):
    "Your Claude settings file couldn't be read, so EasyNotch left it unchanged."
  - **Note text:**
    "Changes apply to Claude Code sessions you start after connecting. Your settings are backed up to settings.json.easynotch-backup. Key order and spacing in settings.json may change."
  - **Tab visibility:** point to the Modules pane, the same way the other feature panes do.

- [ ] **Step 2: Build and check by hand.**
  - Build, open Settings → Claude Code, and click Connect.
  - `jq '.hooks.PermissionRequest, .statusLine' ~/.claude/settings.json` shows our entries, and
    your `PreToolUse` hook is still there.
  - Click Disconnect, then `diff <(jq -S . ~/.claude/settings.json) <(jq -S . ~/.claude/settings.json.easynotch-backup)` shows no differences.

- [ ] **Step 3: Commit.** `git commit -m "Add Claude Code settings pane"`

---

### Task 8: End-to-end check and docs

**Files:**
- Modify:
  - `docs/QA_CHECKLIST.md` (a new "Claude Code" section, with the items from spec §7)
  - `docs/BLUEPRINT.md` (D15, plus the roadmap)
  - `docs/DEVELOPMENT.md` (a Claude area: socket path, the `echo … | easynotch-claude permission` trick, Unix socket path length limit)
  - `README.md` (the feature, and exactly what Connect changes)
- Run: `graphify update .`

- [ ] **Step 1: Write the QA section,** then go through it with a real `claude` session:
  - allow
  - deny (Claude says it was denied)
  - two sessions in different folders that queue up
  - quitting EasyNotch while a request waits (the terminal prompt appears)
  - pressing Ctrl-C in Claude while a request waits (the request leaves the notch)
  - hiding the Claude tab (the terminal prompt appears)
  - usage bars after one message
  - keyboard only (Return and Escape)
  - VoiceOver reads the summary
  - moving the app (Reconnect)
  - Disconnect

  Write down each result.
- [ ] **Step 2: Update the docs** listed above. Leave CLAUDE.md Status unchanged until release.
- [ ] **Step 3: Run the full build and tests one last time.** Expected: every test passes (155 existing plus the new ones).
- [ ] **Step 4: Commit.** `git commit -m "Document the Claude Code integration"`, then run `graphify update .`.
