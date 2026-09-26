# EasyNotch

Native macOS app that turns the MacBook notch into a hover-to-expand panel with:
- music controls for Spotify and Apple Music
- a file shelf with AirDrop
- a Pomodoro timer

Everything is customizable.

The owner is new to macOS development and to Claude Code. Explain non-obvious decisions in a
sentence or two, and prefer simple, readable code over clever code.

## Status
- **Phase 0 (setup): done.** The skeleton agent app (menu-bar icon with Quit) builds, its tests
  pass, and it runs.
- **Phase 1 (notch shell): done.** Hover open/close, tabs with placeholders, and a Settings
  window (Behavior and Size panes, live size preview). 26 tests pass; the owner walked through
  the QA checklist.
- **Phase 2 (Pomodoro + compact live activity): done, but the owner hasn't hands-on tested
  it yet.** The owner was away; Claude verified it with unit tests (47) and Debug-flag runs.
  The owner should walk through `docs/QA_CHECKLIST.md` Phase 2.
- **Phase 3 (music): committed.** 65 tests pass. Real playback with Automation permission is
  still to be checked by the owner (`docs/QA_CHECKLIST.md` Phase 3).
- **Phase 4 (shelf + AirDrop): done.** 94 tests pass, and the owner tested drag in and out,
  AirDrop, Share, and Quick Look. Decided: keep links and ask once for Downloads, Desktop, and
  Documents. That macOS prompt is expected.
- **Every feature from the original request is built.**
- **Phase 5 (customization): committed.** 112 tests pass.
  - **Verified:** full-screen hiding (Claude, live), animation presets and tab reorder arrows
    (owner).
  - **After owner feedback:** the "System" accent now uses the real macOS accent, and tabs can
    be reordered by dragging rows.
  - **Owner hasn't confirmed yet:** those two fixes, the shortcut, launch at login, the
    virtual notch on an external monitor, click mode, and the right-click menu.
- **Next:** Phase 6 (polish and a GitHub release). Also trim this file below about 100 lines.
- **Signing:** Apple Development, owner's Personal Team `Y4Q9CP9K8V`. If a build ever says a
  certificate or profile is missing, add `-allowProvisioningUpdates`.
- **Decisions:** approved defaults plus GitHub Releases distribution; see `docs/BLUEPRINT.md`
  §13 and D12.
- Roadmap and acceptance criteria are in `docs/BLUEPRINT.md` §12. Update this section whenever a
  phase finishes.

## Docs
- `docs/BLUEPRINT.md`: architecture, decisions D1–D11, roadmap. Read the relevant section before
  structural work, and update it when a decision changes.
- `docs/GETTING_STARTED.md`: beginner guide, setup steps, glossary.

## Commands (work from Phase 0 on)
```bash
xcodegen generate   # regenerate EasyNotch.xcodeproj from project.yml
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Debug -derivedDataPath build build
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -derivedDataPath build test
killall EasyNotch; open build/Build/Products/Debug/EasyNotch.app
open build/Build/Products/Debug/EasyNotch.app --args -OpenSettingsOnLaunch YES   # Debug only: opens Settings at launch
# Debug only: put a file on the shelf (writes the real shelf.json; delete it after testing)
open build/Build/Products/Debug/EasyNotch.app --args -AddToShelf /path/to/file
# Debug only: start a 1-minute timer without saving any settings (launch args override UserDefaults for one run)
open build/Build/Products/Debug/EasyNotch.app --args -StartPomodoroOnLaunch YES -pomodoro.focusMinutes 1 -pomodoro.notifications NO
```
Test runs write real timer state; clean up with
`defaults delete com.seanl.easynotch pomodoro.engine` (plus `pomodoro.statsDay` and
`pomodoro.sessionsOnStatsDay`).

## Architecture rules
- **Stack:**
  - Swift 6, macOS 14+.
  - SwiftUI for all views. Use AppKit only where SwiftUI can't do the job: `NSPanel`,
    `NSEvent` monitors, `NSSharingService`.
  - No third-party packages unless the owner agrees.
- **Project file:** `project.yml` is the source of truth. Never hand-edit
  `EasyNotch.xcodeproj`; it's generated and gitignored. Rerun `xcodegen generate` after adding
  or removing files or changing build settings.
- **Layers point down only:** App → Notch → Features → Settings/Shared. `Features/Music`,
  `Features/Shelf`, and `Features/Pomodoro` never reference each other.
- **Services** are `@Observable` classes, created once in `AppServices` and injected with
  `.environment`. No hidden singletons.
- **Logic lives in plain, unit-tested types:** `NotchGeometry`, `PomodoroEngine`, `ShelfStore`,
  and active-player selection. Keep views thin.
- **Threading:** default actor isolation is MainActor. Blocking work (AppleScript, file I/O,
  thumbnails) goes in an `actor` or an async task. Never block the main thread.

## Gotchas
- **Never hardcode the notch size.** Read `NSScreen.safeAreaInsets.top` and
  `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. This Mac's notch is 185×32 pt on a
  1512×982 pt display; use it for tests only.
- **Only send Apple Events to Spotify or Music if `NSRunningApplication` shows it running.**
  Otherwise the event launches the player.
- **App Sandbox is OFF, Hardened Runtime is ON.** Apple Events need the
  `com.apple.security.automation.apple-events` entitlement and `NSAppleEventsUsageDescription`.
- **Keep the Apple Development signature (never ad-hoc).** Automation permissions are tied to
  the code signature. Reset them with `tccutil reset AppleEvents com.seanl.easynotch`.
- **The panel ignores mouse events while closed** so menu-bar clicks pass through. Hover comes
  from global `NSEvent` mouse monitors, which need no permission. Keyboard monitors would need
  Accessibility, so don't add them without asking.
- **Mark `Shape` types and similar pure-SwiftUI conformances `nonisolated`.** Because the
  default isolation is MainActor, the conformance otherwise fails with "crosses into main
  actor-isolated code".
- **The screen-control tool can't grant EasyNotch while it runs from `build/`,** and its
  screenshots black out EasyNotch's windows. Verify behavior through `.debug` logs, and leave the
  visual checks to the owner.
- **zsh doesn't word-split unquoted variables.** `open … --args $ARGS` passes a single
  argument. Write the arguments inline, or use `${=ARGS}`.
- **Always pass a `tolerance` to long `Task.sleep` calls** that must fire on time. Without one,
  macOS woke a 60 s sleep about 4 s late.
- **Pomodoro holds a `ProcessInfo` activity while running,** so App Nap doesn't throttle the
  countdown.
- **Music permission:** never trigger the Automation prompt from background code. Check it
  with `AppleScriptRunner.permission(askIfNeeded: false)`, and only pass `askIfNeeded: true` or
  run commands in response to a user action.
- **Listen to other apps' distributed notifications with `DistributedNotificationObserver`**
  (`.deliverImmediately`). The block-based API holds notifications while EasyNotch is inactive,
  which is nearly always.
- **Drag detection must never read another app's pasteboard contents.** Only the change counter
  and the list of types (see `FileDragDetector`), so no privacy prompt appears.
- **Present system UI (AirDrop, Quick Look) only after `NSApp.activate()`.** The notch panel
  can't become key.
- **Full-screen hiding uses undocumented `CGS*` functions** (D13), looked up with `dlsym` in
  `FullScreenDetector`. Never call them directly, and keep the graceful fallback.
- **`AppSettings.isRecordingShortcut` is a transient, unsaved flag.** It pauses the global hot
  key while the recorder listens.
- **SwiftUI's `.onMove` does nothing inside a `Form` on macOS.** Reorder with
  `.draggable` / `.dropDestination` on each row (see `ModulesPane`).
- **For the system accent, use `Color(nsColor: .controlAccentColor)`.** SwiftUI's
  `.accentColor` came out grey.
- **Features never reference each other.** Helpers shared between features go in `Shared/`
  (e.g. `SecondsTimeline`).
- **Continuous decorative motion uses Core Animation layers, not SwiftUI.** See `AudioBars`:
  the render server animates them at no app CPU cost.
- **Wing width can be 0, so compact content must shrink** (`.minimumScaleFactor`, max frames),
  and the wings clip.
- **Minimum open size is 560×190 pt, set by the Music tab's layout.** If a tab's layout grows,
  re-check it at the minimum and raise `NumericSetting.expandedWidth/Height` if needed.
- **Idle CPU must stay near 0%.** No always-running timers or polling; stay event-driven.
- **zsh has a built-in `log` command.** Call Apple's tool as `/usr/bin/log show|stream`.
  Only `.notice` and higher are saved to the log; `.info` and `.debug` appear only in a live
  stream.
- **Harmless noise during `xcodebuild test`:** "linkd.autoShortcut" connection errors, and
  "Executed 0 tests" from XCTest. The results that count are the Swift Testing `✔` lines.

## Conventions
- One main type per file, and the file name matches the type. Folder layout:
  `docs/BLUEPRINT.md` §9.
- Tests use Swift Testing (`import Testing`, `@Test`). New logic ships with tests.
- Log with `os.Logger` (`Log.notch`, `Log.music`, …). Never use `print`.
- Each new user-facing option goes into `AppSettings` with a default, plus a control in its
  settings pane. Also add it to its type's `.all` registry and to `reload()`; export, import,
  and reset depend on both. `SettingsTransferTests` checks the registry count.
- **Before calling a phase done:**
  1. The build and tests pass.
  2. Walk through `docs/QA_CHECKLIST.md`.
  3. Update Status above.
  4. Ask before committing.
