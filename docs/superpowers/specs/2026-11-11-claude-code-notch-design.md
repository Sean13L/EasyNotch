# Claude Code in the Notch: Design

Date: 2026-11-11 · Status: draft for owner review · Branch: `notch-attention`

## 1. Goal

Let the notch answer **Claude Code CLI** permission requests (Allow or Deny, which also
covers accepting file edits) and show **subscription usage limits**, so the owner doesn't
have to switch to the terminal every time Claude is waiting.

### Agreed in brainstorming
- **Target:** Claude Code CLI only. The Claude desktop app has no public integration API.
- **Scope of this spec:** permissions and usage. Replying to Claude, including
  `AskUserQuestion` and `ExitPlanMode`, gets its own spec later.
- **Attention:** a quiet wing alert that stays until the notch is opened, like meeting alerts.
  The notch does not open on its own.
- **Waiting:** the notch is the only place to answer. The terminal prompt appears only when
  EasyNotch can't decide: it isn't running, the connection drops, or the hook times out.
- **Multiple sessions:** supported. Requests wait in a queue, oldest first, each labelled
  with its project folder.
- **Usage:** only the 5-hour and weekly limits, as percentage used and time until reset.
- **Setup:** a Connect button in Settings that backs up and edits `~/.claude/settings.json`,
  and a Disconnect button that removes exactly what Connect added.
- **Transport:** a helper tool bundled with the app that talks to EasyNotch over a private
  Unix domain socket.

### Out of scope (YAGNI)
"Always allow" rules (`updatedPermissions`), editing the command before allowing it
(`updatedInput`), answering questions or plans, session context or cost, low-limit wing
warnings, the Claude desktop app.

## 2. Background: Claude Code facts this design depends on
Checked in the current docs (code.claude.com/docs/en/hooks, /statusline) on 2026-11-11:
- A `PermissionRequest` command hook reads the request as JSON on stdin and may print
  `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"|"deny","message":"…"}}}`.
  If it exits without a decision, the normal permission flow continues and the terminal
  prompt appears. **Deny rules still win** over a hook's `allow`.
- The hook `timeout` defaults to 600 s and can be set per hook. When the timeout runs out,
  Claude Code cancels the hook and discards its output, so no decision is made and the
  terminal prompt appears.
- The status line command gets session JSON on stdin every update. `rate_limits.five_hour`
  and `rate_limits.seven_day`, each with `used_percentage` (0–100) and `resets_at` (Unix
  seconds), appear only for Pro, Max, and Ultra subscribers, only after the first API
  response, and either window may be missing.
- `AskUserQuestion` and `ExitPlanMode` also arrive as `PermissionRequest`s and need
  `updatedInput`, so this spec passes them through untouched.

## 3. Components

### 3.1 Helper tool: `easynotch-claude` (new command-line target)
- Built from `project.yml` as a `tool` target and copied into
  `EasyNotch.app/Contents/Helpers/easynotch-claude`. Signed by the same certificate as the
  app (`scripts/release.sh` signs it before the app).
- **`easynotch-claude permission`**
  1. Reads the hook JSON from stdin.
  2. If `tool_name` is `AskUserQuestion` or `ExitPlanMode`, exits 0 with no output
     (the terminal handles it).
  3. Builds a `ClaudeBridgeMessage.permissionRequest` with:
     - `tool`: for example `Bash` or `Edit`
     - `summary`: `tool_input.command` for Bash, `tool_input.file_path` for
       Edit/Write/MultiEdit/NotebookEdit, otherwise the tool name
     - `project`: the last path component of `cwd`
     **Nothing else from the input is sent:** no file contents, no transcript path.
  4. Connects to the socket. If that fails, exits 0 with no output.
  5. Waits for a single reply line. If the reply is `allow` or `deny`, prints the hook
     decision JSON (a deny includes the message "Denied from EasyNotch.") and exits 0. If the
     connection closes or the reply is invalid, exits 0 with no output.
- **`easynotch-claude statusline [--then <command>]`**
  1. Reads stdin.
  2. If `rate_limits` is present, sends a `ClaudeBridgeMessage.usage` without waiting for a
     reply, and ignores a failure to connect.
  3. If `--then` is given, runs that command with `/bin/sh -c`, passes it the same stdin,
     and prints its stdout. Otherwise it prints nothing.
- Has no UI and no AppKit. It links only Foundation and the shared message file.

### 3.2 Shared: `ClaudeBridgeMessage` (`Shared/ClaudeBridgeMessage.swift`, in both targets)
- `Codable` enum, sent as **one line of JSON** ending in `\n`:
  - `permissionRequest(tool: String, summary: String, project: String)`
  - `usage(fiveHour: Window?, sevenDay: Window?)`, where `Window = { usedPercentage: Double, resetsAt: Date }`
  - `decision(allow: Bool)` (app → helper)
- `static let maxLineBytes = 64 * 1024`. Decoding rejects longer lines, and rejects any
  `summary` over 4 KB once trimmed.
- `static func socketURL(appSupport: URL) -> URL` →
  `<appSupport>/EasyNotch/claude.sock`.

### 3.3 App: `Features/Claude/`
| Type | Kind | Job |
|---|---|---|
| `ClaudeBridgeServer` | `actor` | Creates the folder (0700), removes any leftover socket, binds and listens (socket 0600), and accepts connections using GCD read sources (event-driven, no polling). Reads one line per connection and passes it to `ClaudeService`. Closes a connection if a line is too long or invalid. Calls back when a peer hangs up. |
| `ClaudeService` | `@Observable`, created in `AppServices` | Holds `pending: [ClaudeRequest]` (FIFO; `ClaudeRequest` has an `id`, `tool`, `summary`, `project`, `receivedAt`) and `usage: ClaudeUsage?` (the two windows plus `updatedAt`). `allow(id)` / `deny(id)` send the decision and remove the request. A peer hangup removes the request without sending anything. Starts and stops the server based on whether Claude Code is connected. |
| `ClaudeSetup` | plain struct, unit-tested | `connect(settingsURL:helperPath:)`, `disconnect(settingsURL:)`, and `status(settingsURL:helperPath:) -> .disconnected / .connected / .needsReconnect`. Details in §5. |
| `ClaudeView` | SwiftUI | The Claude tab (§4). |
| `ClaudePane` | SwiftUI | The settings pane (§4.4). |

### 3.4 Changes to existing code
- `NotchModule`: add `.claude` (SF Symbol `terminal`; the Claude logo isn't used because it's
  a trademark).
- `LiveActivity`: add `.claudeRequest` (module `.claude`) and `Candidates.claudeWaiting`.
  In `resolve`, it ranks as an alert **right after** `pomodoroAlert` and before
  the charging flash. A waiting request blocks Claude, so it outranks informational alerts.
  It stays until the notch is opened, like `MeetingAlerts`.
- `AppSettings`: add `showClaudeTab` (default `true`; while disconnected the tab shows the
  "Not connected" state from §4.3) through `.all` and
  `reload()`, plus `claudeOriginalStatusLine: String?` (§5), which is internal and not
  exported.
- `AppServices`: creates and starts `ClaudeService`, and injects it with `.environment`.
- Layers: `Features/Claude` imports only `Shared`/`Settings`. No other feature references it.

## 4. UI

### 4.1 Wings (notch closed, ≥1 request waiting)
Left: the `terminal` symbol and the waiting count. Right: the oldest request's summary, cut
off in the middle if needed. The alert stays until the Claude tab is on screen (opening the
notch on another tab doesn't count), then clears while requests are still waiting. A new request arriving later brings it back.

### 4.2 Claude tab: request waiting
```
┌───────────────────────────────────────────────┐
│ EasyNotch · Bash                    1 of 2    │
│ npm test -- --filter Pomodoro                 │
│            [ Deny ]      [ Allow ]            │
├───────────────────────────────────────────────┤
│ 5h   ████████░░░░░░  42%   resets in 2h 10m   │
│ Week ███░░░░░░░░░░░  18%   resets Thu         │
└───────────────────────────────────────────────┘
```
- The summary is shown in a monospaced font, up to 3 lines, ending in "…". The full text
  appears in a tooltip and in the accessibility label.
- Answer by clicking Allow or Deny. The notch never takes keyboard focus, so Return and Escape don't answer (this also stops a stray keypress approving anything).
- After you answer, the next request appears. When the queue is empty, only usage is shown.

### 4.3 Claude tab: other states
- **Not connected:** "Connect Claude Code to answer permission requests from the notch."
  with an "Open Settings" button.
- **Needs reconnect** (the app has moved): "EasyNotch moved. Reconnect in Settings."
- **No usage yet:** "Usage appears after your next Claude message (Pro, Max, and Ultra
  plans)."
- **Usage present:** the bars, plus "Updated N min ago" from `updatedAt`. This text refreshes
  only while the tab is visible, using the existing `SecondsTimeline` helper (no timer runs
  in the background).
- Bar colours meet WCAG AA against the notch background and use `NotchAccent`.

### 4.4 Settings pane
Status line ("Connected", "Not connected", or "EasyNotch moved — reconnect"), a
Connect / Disconnect / Reconnect button, the "Show Claude tab" toggle, and a note:
"Changes apply to Claude Code sessions you start after connecting. Your settings are backed
up to settings.json.easynotch-backup."

## 5. Connect and Disconnect (`ClaudeSetup`)

Settings file: `~/.claude/settings.json`. If it's missing, start from `{}`.
Our entries are identified by **their command containing the helper's path**.

**Connect**
1. If the file exists but isn't a valid JSON object: **stop**, change nothing, and show "Your
   Claude settings file couldn't be read, so EasyNotch left it unchanged."
2. Copy the file to `settings.json.easynotch-backup`, replacing any older backup.
3. Remove any of our earlier entries (this makes Reconnect safe), then add to
   `hooks.PermissionRequest` this matcher group:
   `{"matcher":"*","hooks":[{"type":"command","command":"'<helper>' permission","timeout":86400}]}`.
   Existing groups and other events, such as the owner's `PreToolUse`, are left alone.
   86400 s (24 h) stands in for "indefinitely". The implementation plan's first step
   checks that Claude Code accepts this value. If it doesn't, use the largest value it does
   accept.
4. Status line:
   - If there's none: set `{"type":"command","command":"'<helper>' statusline"}`.
   - If there's one that isn't ours: save its `command` in `claudeOriginalStatusLine`,
     then set our command with `--then '<original, shell-quoted>'`, keeping the other
     fields (for example `padding`).
5. Write the file atomically with `.prettyPrinted` and `.sortedKeys`. **Key order and
   spacing may change** from the original (stated in the pane note and docs).

**Disconnect**
1. If the file isn't valid JSON, stop as in Connect step 1.
2. Remove hook handlers whose command contains the helper path. Drop any matcher groups or
   events left empty.
3. If the status line is ours: restore `claudeOriginalStatusLine` if it's set, otherwise
   remove the key, then clear the saved value.
4. Write the file atomically. The backup is kept.

**Status at launch:** our entries are found but point to a different helper path →
`.needsReconnect`. Running sessions keep their old settings. That's fine, because a missing
helper means the terminal prompt appears.

## 6. Error handling summary
| Situation | Result |
|---|---|
| EasyNotch not running or not connected | The helper can't connect → no decision → terminal prompt |
| EasyNotch quits while a request waits | The connection drops → no decision → terminal prompt |
| The user stops Claude (Ctrl-C) | The helper is killed → peer hangup → the request leaves the queue |
| The hook times out | Claude Code discards the hook → terminal prompt |
| Oversized or invalid line | The server closes the connection → terminal prompt |
| A deny rule matches | Claude Code denies even if the notch allows (expected) |
| The settings file can't be read | Connect and Disconnect change nothing and show an error |

Logging uses a new `Log.claude` category: connection events and the tool name only, never
the summary.

## 7. Testing
Swift Testing (`import Testing`), in `EasyNotchTests`:
- `ClaudeBridgeMessageTests`: round-trip each case, reject lines over 64 KB and invalid JSON,
  trim the summary to the limit.
- `ClaudeSetupTests` (temporary folders): missing file, `{}`, existing `PreToolUse` kept,
  existing status line wrapped and restored, Reconnect replaces rather than duplicates,
  invalid JSON refused with the file unchanged, Connect followed by Disconnect leaves an
  equal JSON object, `.needsReconnect` detection.
- `ClaudeServiceTests`: FIFO order, `allow`/`deny` reaching the right connection (using a
  fake connection), hangup removing the request, usage updating `updatedAt`, a missing
  window staying missing.
- `LiveActivityTests`: `claudeWaiting` beats charging, meeting, and battery but not the
  Pomodoro alert, and maps to `.claude`.
- `ClaudeBridgeRoundTripTests`: the real server in a temporary folder, plus a client using the
  helper's connection code, covering allow, deny, and the server stopping in the middle of a
  request.
- `SettingsTransferTests`: the new exported setting is registered.

`docs/QA_CHECKLIST.md` gets a "Claude Code" section: connect, run a real session, allow,
deny, two sessions queueing, quitting EasyNotch while a request waits (the terminal prompt
appears), moving the app (Reconnect), disconnecting and checking `settings.json`, Return and
Escape doing nothing, and VoiceOver reading the summary.

## 8. Docs to update
`docs/BLUEPRINT.md` (new D15: Claude Code bridge over a Unix socket and bundled helper;
roadmap), `docs/DEVELOPMENT.md` (Claude area: socket path, testing the helper by hand with
`echo '{…}' | easynotch-claude permission`), `README.md` (the feature, and what Connect
changes), and the CLAUDE.md Status section when it ships.

## 9. Global standards checklist
- **Applied:**
  - **16:** the helper sends only the tool, summary, and project, and nothing is stored on
    disk.
  - **21:** an SF Symbol rather than the Claude trademark.
  - **28:** AA contrast for the bars and text.
  - **29:** keyboard access and focus, plus accessibility labels.
  - **Never-blocking rule:** the server runs in an `actor`.
  - **Event-driven idle:** GCD sources, no polling.
- **Skipped:**
  - **A1–A12:** there's no server, database, accounts, or uploads. The only connection
    point is a socket file readable only by the owner.
  - **B13–B22 and C23–C26:** this feature adds no website, tracking, payments, or marketing
    text.
