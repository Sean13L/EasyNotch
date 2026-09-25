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
- **Now:** Phase 1, the notch shell. Plan it in Plan mode and spike the `NotchPanel` first.
- **Signing:** ad-hoc for now (there's no Apple ID in Xcode yet). Switch to an Apple
  Development identity before Phase 3.
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
```

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
- **Sign with the Apple Development identity, not ad-hoc.** Automation permissions are tied to
  the code signature. Reset them with `tccutil reset AppleEvents com.seanl.easynotch`.
- **The panel ignores mouse events while closed** so menu-bar clicks pass through. Hover comes
  from global `NSEvent` mouse monitors, which need no permission. Keyboard monitors would need
  Accessibility, so don't add them without asking.
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
  settings pane.
- **Before calling a phase done:**
  1. The build and tests pass.
  2. Walk through `docs/QA_CHECKLIST.md`.
  3. Update Status above.
  4. Ask before committing.
