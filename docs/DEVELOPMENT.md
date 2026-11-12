# Development notes

Practical knowledge for working on EasyNotch: debug tricks and the lessons learned while
building it. For architecture and decisions, see [BLUEPRINT.md](BLUEPRINT.md). For a
beginner's introduction, see [GETTING_STARTED.md](GETTING_STARTED.md).

## Debug-only launch options
Launch arguments override saved settings for one run without changing them.

```bash
# Open Settings at launch
open build/Build/Products/Debug/EasyNotch.app --args -OpenSettingsOnLaunch YES
# Start a 1-minute timer (notifications off for this run)
open build/Build/Products/Debug/EasyNotch.app --args -StartPomodoroOnLaunch YES -pomodoro.focusMinutes 1 -pomodoro.notifications NO
# Put a file on the shelf (writes the real shelf.json)
open build/Build/Products/Debug/EasyNotch.app --args -AddToShelf /path/to/file
# Any setting works the same way, e.g. show the notch on every screen
open build/Build/Products/Debug/EasyNotch.app --args -notch.displayMode all
# Sample the system monitor every second and log each sample (measures its cost)
open build/Build/Products/Debug/EasyNotch.app --args -SampleSystemOnLaunch YES
```

**Clean up after test runs.**
- **Timer state:** `defaults delete com.seanl.easynotch pomodoro.engine`, plus
  `pomodoro.statsDay` and `pomodoro.sessionsOnStatsDay`.
- **Shelf:** delete `~/Library/Application Support/EasyNotch/shelf.json`.

## Tooling
- **zsh has a built-in `log` command.** Call Apple's tool as `/usr/bin/log show|stream`. Only
  `.notice` and above are saved; `.info` and `.debug` appear only in a live stream:
  `/usr/bin/log stream --level debug --predicate 'subsystem == "com.seanl.easynotch"'`.
- **zsh doesn't word-split unquoted variables.** `open … --args $ARGS` passes one argument.
  Write the arguments inline, or use `${=ARGS}`.
- **Harmless noise during `xcodebuild test`:** "linkd.autoShortcut" connection errors, and
  "Executed 0 tests" from XCTest. The results that count are the Swift Testing `✔` lines.
- **Claude's screen-control tool can't be granted EasyNotch,** and its screenshots black out
  EasyNotch's windows. Verify with `.debug` logs and window listings
  (`CGWindowListCopyWindowInfo`), and leave the visuals to a person.
- **Signing:** if a build says a certificate or profile is missing, add
  `-allowProvisioningUpdates`.
- **App icon:** `scripts/make-icon.sh` redraws every size from `scripts/make-icon.swift`.

## Swift 6 and concurrency
- The default isolation is MainActor. Mark `Shape` types and other pure conformances
  `nonisolated`. Otherwise you get "conformance crosses into main actor-isolated code".
- AppKit classes whose initializers aren't MainActor (e.g. `NSMenuItem`) can't be subclassed
  with MainActor initializers. Attach a target object instead (see `NotchContextMenu`).
- A closure stored for later use from another thread must be `@MainActor` (implicitly
  Sendable). See `ScreenManager.observe`.
- `#expect(...)` can't contain a mutating call. Store the result in a variable first.
- Always give long `Task.sleep` calls an explicit `tolerance` if they must fire on time.
  Without one, macOS woke a 60 s sleep about 4 s late.

## The notch window
- **Never hardcode the notch size.** Read `safeAreaInsets.top` and
  `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. The owner's Mac is 185×32 pt on
  1512×982 pt.
- The panel ignores the mouse while closed, so menu-bar clicks pass through. Hover, clicks,
  and drags come from global and local `NSEvent` monitors. Mouse monitoring needs no
  permission; keyboard monitoring would need Accessibility, so avoid it.
- Mouse moves arrive constantly. Reject far-away points before doing any other work (see
  `NotchViewModel.pointerMoved`).
- **Full-screen detection** uses undocumented `CGS*` functions looked up with `dlsym` (see
  `FullScreenDetector`, BLUEPRINT D13). Never link them directly, and keep the fallback.
- **The global shortcut** uses Carbon `RegisterEventHotKey` (no permission needed).
  `AppSettings.isRecordingShortcut` pauses it while the recorder listens.
- **System UI** (AirDrop, Quick Look, context menus) needs `NSApp.activate()` first, because
  the notch panel can't become key.
- **Continuous decorative motion** uses Core Animation layers (see `AudioBars`), which cost
  no app CPU. SwiftUI animations would redraw every frame.
- **Wing width can be 0,** so compact content must shrink (`.minimumScaleFactor`, max
  frames), and the wings clip.
- **The minimum open size, 560×190 pt, comes from the Music tab.** Re-check it if a tab's
  layout grows.

## Music
- Only send Apple Events to a player that `NSRunningApplication` says is running. Otherwise
  the event launches it.
- Never trigger the Automation prompt from background code. Check it with
  `AppleScriptRunner.permission(askIfNeeded: false)`. Ask, or run commands, only in response
  to a user action.
- Listen to other apps' distributed notifications with `DistributedNotificationObserver`
  (`.deliverImmediately`). The block-based API holds them while EasyNotch is inactive, which
  is nearly always.
- Automation permission is tied to the code signature. Always keep the Apple Development
  signature, never ad-hoc. Reset with `tccutil reset AppleEvents com.seanl.easynotch`.
- **Check permission by process ID, not bundle ID.** After Spotify restarted itself (seen with
  1.3.3 on macOS 27), macOS kept an entry for the dead process. A bundle-ID
  `AEDeterminePermissionToAutomateTarget` was sent to that entry and never returned. That
  froze the AppleScript queue, so there was no cover, position, or controls. To spot it,
  `sample EasyNotch` shows the queue stuck in that call.
- **Cover downloads must expect the internet to drop out.** `ArtworkDownloader` gives each
  attempt 10 s (the system default is 60 s) and retries after 3, 10, and 30 s. If every
  attempt fails, the track isn't marked done, so the next update tries again. Failures are
  logged at `notice` level, which macOS keeps. Debug lines aren't stored, so check the
  stored log with `log show --predicate 'process == "EasyNotch"'` and look for NSURLError
  -1001 (timed out).

## Spatial Audio (Spotify)
- **Off for new installs.** It relays Spotify through EasyNotch (a Core Audio process tap, an
  aggregate device, then `AVSampleBufferAudioRenderer`) so AirPods can apply Spatial Audio.
  Apple Music doesn't need it.
- **Permission is only asked by a user action.** `spatialAudio.permissionConfirmed` is set after a
  successful start and cleared after a failed one. Background starts only run when it's set, so
  they never trigger the "Screen & System Audio Recording" prompt.
- **Needs macOS 14.2.** The tap API isn't in 14.0. The relay is `@available(macOS 14.2, *)`, and the
  controller reports "Needs macOS 14.2 or later" on older systems.
- **Quit Spatial Relay (shevlfs) first.** Both tap Spotify, and they conflict.

## Shelf
- **Drag detection never reads another app's pasteboard contents,** only its change counter
  and list of types (see `FileDragDetector`). So no privacy prompt appears.
- **Tiles drag through AppKit** (`FileDragSource`), so we know whether a drop happened.
  SwiftUI's `.onDrag` can't tell us.
- **Files in Downloads, Desktop, and Documents trigger a one-time macOS prompt** (decided:
  keep links, ask once). If access is denied, tiles show "No access", not "Missing".
- **Compare file paths in their canonical form.** `/var/…` and `/private/var/…` are the same
  folder.

## Pomodoro
- The engine stores end times, not countdowns, so sleep can't make it drift.
- The controller holds a `ProcessInfo` activity while running, so App Nap doesn't throttle
  the once-a-second redraw.

## Calendar
- **Calendars needs the entitlement `com.apple.security.personal-information.calendars`.**
  Under the Hardened Runtime, a missing entitlement means no prompt and no events, with no error.
  It also needs `NSCalendarsFullAccessUsageDescription` in Info.plist.
- **Ask for access only when the user presses the button** (`requestFullAccessToEvents`). In the
  background, only check `EKEventStore.authorizationStatus`.
- **Never log event titles or notes.** Log counts only.
- **An `EKEventStore` made before access was granted can keep returning nothing.**
  `CalendarService` replaces it when access turns on, including when that happens in System
  Settings.
- **Don't poll.** `CalendarService` sleeps until `MeetingSchedule.nextChange`, and reloads on
  `EKEventStoreChanged`, day change, and wake.

## Battery
- **`IOPSNotificationCreateRunLoopSource`'s callback is a plain C function.** Pass `self`
  through the context pointer (`Unmanaged`), not a capture.
- **A plugged-in Mac that isn't charging is usually holding at 80% (Optimized Charging).** It
  isn't an error. `BatterySnapshot.isHoldingCharge` covers it.
- **Health:** `AppleSmartBattery` → `BatteryData` → `NominalChargeCapacity` / `DesignCapacity`.
  A new battery can read above 100%, so it's capped.
- **Compare with `pmset -g batt`** and `ioreg -rn AppleSmartBattery`.

## System monitor
- **Nothing samples unless the System tab is open or the transfer indicator is on.** Keep it
  that way.
- **`volumeAvailableCapacityForImportantUsageKey` costs about 15 ms** (macOS totals up purgeable
  space), and at once a second it also grew memory. It's read when the tab opens and then every
  30 s. The other readings cost under 0.05 ms.
- **Keep one `mach_host_self()`.** Each call adds a reference to the port.
- **`getifaddrs` byte counters are 32-bit and wrap around.** Use wrapping subtraction (`&-`),
  and skip `lo0`, `utun*`, and other virtual interfaces.

## Claude Code
- **How it fits together:** Claude Code runs `EasyNotch.app/Contents/Helpers/easynotch-claude`
  as a `PermissionRequest` hook and as the status line. The helper talks to the app over
  `~/Library/Application Support/EasyNotch/claude.sock` (D15). `ClaudeBridgeServer` is the
  app side, `ClaudeService` holds the queue, `ClaudeSetup` edits `~/.claude/settings.json`.
- **Try the helper by hand,** with EasyNotch running and connected:
  ```bash
  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/tmp/demo"}' \
    | build/Build/Products/Debug/EasyNotch.app/Contents/Helpers/easynotch-claude permission
  ```
  Allow or Deny in the notch and the JSON reply prints. No output means "no decision", which
  is what Claude Code treats as "show the terminal prompt".
- **Unix socket paths are limited to 104 bytes** on macOS. The real path is short enough, but
  tests must not use the long temporary folder: they use `/tmp/en-xxxx/s.sock`.
- **No answer is always safe.** Hiding the Claude tab, Disconnect, quitting, or a request
  arriving with nothing listening closes the connection with no reply, so Claude Code asks in
  the terminal. So does having no notch on screen (lid closed with "built-in only", or every
  notch hidden over full screen: `ScreenManager.hasVisibleNotch`), and a 33rd waiting request
  (`ClaudeService.maxPending`).
- **One message per connection.** `Connection` delivers its first line only and then just
  watches for a hangup. A request whose connection already closed (a fast Disconnect →
  Connect) is ignored via the thread-safe `Connection.isClosed`.
- **Out of file descriptors** (`EMFILE`/`ENFILE` from `accept`), the listener is suspended
  instead of spinning, and resumed when one of our connections closes.
- **The Claude alert clears only when the Claude tab is on screen** (`ClaudeView` calls
  `tabAppeared`/`tabDisappeared`), not on any notch open: a Pomodoro alert or a file drag
  opens the notch on another tab. In `.needsReconnect` (the app was moved) no listener runs at all.
- **Only the front request is answerable, and only 0.5 s after it became the front**
  (`ClaudeService.answerGuard`). When a request is answered or goes away, the next one slides
  under the pointer; the guard stops a stray click aimed at the old one from approving a
  command the user never read. It covers answers, Ctrl-C in Claude, and new arrivals. There
  are no keyboard shortcuts: the notch panel never becomes key (`NotchPanel.canBecomeKey`).
- **Our entries are recognised by a command containing `easynotch-claude`.** Disconnect
  removes anything matching, even if the path is from another copy of the app.
- **Backups:** `settings.json.easynotch-backup` is written only the first time (when the file
  has none of our entries), so Reconnect can't overwrite the untouched original. It keeps the
  settings file's permissions. A status line that was already there is saved whole in
  `settings.json.easynotch-statusline` and restored on Disconnect.
- **Broken pipe:** the helper ignores SIGPIPE, and a wrapped status-line command run through
  `/bin/sh -c` inherits that. A pipeline such as `… | head` in the user's original status
  line may then print "Broken pipe". Harmless, and left as is.
- **Hook timeout:** we set 86400 s. Claude Code's docs name no maximum (the default is 600 s);
  the QA checklist has an item that confirms a request waiting over 10 minutes still works.
- **Never log the summary:** log the tool name and connection events only (`Log.claude`).
- **Don't touch the real `~/.claude` in tests.** `ClaudeSetup` takes the settings URL, so
  tests use temporary folders.

## Settings and SwiftUI
- **Adding an option:**
  1. Add it to `AppSettings` with a default.
  2. Add it to its type's `.all` registry.
  3. Add it to `reload()`.
  4. Add a control in its pane.

  Export, import, and reset depend on the registry; `SettingsTransferTests` checks the count.
- **SwiftUI's `.onMove` does nothing inside a `Form` on macOS.** Reorder with `.draggable` /
  `.dropDestination` on each row (see `ModulesPane`).
- **For the system accent, use `Color(nsColor: .controlAccentColor)`.** SwiftUI's
  `.accentColor` came out grey.
- **`withObservationTracking` fires just before a value changes.** Re-read it on the next
  main-loop turn (`Task { @MainActor in … }`), then watch again.

## Releasing
Releases are signed with a self-signed certificate named **"EasyNotch Developer"** (BLUEPRINT
D12). It puts no personal details in the app. Because it never changes, users keep their
permissions across updates.

**One-time setup: create the certificate**
1. Open **Keychain Access**. Choose Keychain Access (menu bar) → **Certificate Assistant** →
   **Create a Certificate…**
2. Fill in the form:
   - Name: `EasyNotch Developer`
   - Identity Type: **Self-Signed Root**
   - Certificate Type: **Code Signing**
3. Tick **Let me override defaults**, click Continue, and set **Validity Period** to `3650`
   days.
4. Keep clicking Continue with the defaults, and save it in the **login** keychain.
5. **Back it up:** right-click it → Export → `.p12`, with a password, somewhere safe. If
   it's lost, every user has to re-allow the Spotify/Music permissions once.

**Each release**
1. Bump `MARKETING_VERSION` in `project.yml` and update `SmokeTests`.
2. Run `scripts/release.sh`. It builds Release **unsigned**, signs it with the certificate
   (Hardened Runtime on, no debugging entitlements), and writes `dist/EasyNotch-<version>.zip`
   plus a `.sha256` checksum.
   - **Why unsigned first:** re-signing an app Xcode already signed with Apple Development
     leaves bytes of the old signature in the binary, including the certificate name, which
     contains the owner's email address. v1.0.0 shipped with this. The script now refuses to
     package if "Apple Development" appears anywhere in the app.
3. Unzip a copy somewhere else and open it, to check it works.
4. Tag and publish:
   ```bash
   git tag v<version>
   git push origin main --tags
   gh release create v<version> dist/EasyNotch-<version>.zip --title "EasyNotch <version>" --notes-file <notes>
   ```

**Health check before a release**
- **CPU, memory, energy:** `top -l 6 -s 2 -pid <pid> -stats pid,cpu,mem,power`.
- **Footprint:** `footprint -p <pid>`.
- **Leaks:** `leaks <pid>`. Run it on the Debug build, because Release builds block the tool.

- v1.0.0 measured: 0.0% idle CPU, 29 MB, 0 leaks.
- v1.1.0 measured: 0.0% idle CPU, 40 MB. The System tab costs about 0.8% while open.
