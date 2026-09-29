# EasyNotch

Native macOS app that turns the MacBook notch into a hover-to-expand panel with:
- music controls for Spotify and Apple Music
- a file shelf with AirDrop
- a Pomodoro timer
- next meeting (Calendar), battery & charging, and a system monitor (v1.1)

Everything is customizable. MIT licensed and distributed through GitHub Releases.

The owner is new to macOS development and to Claude Code. Explain non-obvious decisions in a
sentence or two, and prefer simple, readable code over clever code.

## Status
- **v1.2.0: published** at github.com/Sean13L/EasyNotch (2026-09-29), marked Latest.
  - **Music:** cover-colored sound bars (`ArtworkColor`), player-colored shuffle/repeat, and
    clicking the cover opens the player.
  - **Calendar:** a multi-day agenda (`calendarDaysAhead`) and an Internet Accounts hint for
    Google/Outlook.
  - **Beside the notch:** the wings follow the last-viewed tab, and meeting and low-battery
    alerts stay until the notch is opened (`MeetingAlerts`).
  - 155 tests pass.
- **Earlier releases:** v1.1.0 added the Calendar, Battery, and System tabs (BLUEPRINT
  §6.5–6.8), and v1.0.0 covered Phases 0–6. v1.1.1 was built but never published; 1.2.0
  includes it.
- **Releases are signed** by the owner's self-signed "EasyNotch Developer" certificate via
  `scripts/release.sh`, never the Apple Development one (its name contains the owner's email).
  The script builds unsigned first; re-signing left the old certificate's bytes in the binary.
  The v1.0.0 zip was rebuilt cleanly and replaced on GitHub. Commits use the owner's GitHub
  noreply email.
- **Next:** respond to feedback and issues. For updates, follow `docs/DEVELOPMENT.md` →
  Releasing.
- **Signing:** Apple Development, Personal Team `Y4Q9CP9K8V`. Not notarized (BLUEPRINT D12).
- Roadmap: `docs/BLUEPRINT.md` §12. Update this section whenever a phase finishes.

## Docs
- `docs/BLUEPRINT.md`: architecture, decisions (D1–D14), roadmap. Read the relevant section
  before structural work, and update it when a decision changes.
- `docs/DEVELOPMENT.md`: debug launch options, tooling quirks, and lessons learned by area.
  **Read it before working in an area.**
- `docs/QA_CHECKLIST.md`: hands-on test script for each phase.
- `docs/GETTING_STARTED.md`: beginner guide and glossary.

## Commands
```bash
xcodegen generate   # regenerate EasyNotch.xcodeproj from project.yml
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Debug -derivedDataPath build build
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -derivedDataPath build test
killall EasyNotch; open build/Build/Products/Debug/EasyNotch.app
/usr/bin/log stream --level debug --predicate 'subsystem == "com.seanl.easynotch"'   # zsh's `log` is different
```

## Architecture rules
- **Stack:**
  - Swift 6, macOS 14+.
  - SwiftUI for views. Use AppKit only where SwiftUI can't do the job (panels, event
    monitors, sharing, drag sources).
  - No third-party packages unless the owner agrees.
- **Project file:** `project.yml` is the source of truth. Never hand-edit
  `EasyNotch.xcodeproj`; rerun `xcodegen generate` after adding or removing files.
- **Layers point down only:** App → Notch → Features → Settings/Shared. `Features/Music`,
  `Features/Shelf`, and `Features/Pomodoro` never reference each other; shared helpers go in
  `Shared/`.
- **Services** are `@Observable` classes created once in `AppServices` and injected with
  `.environment`. No hidden singletons.
- **Logic lives in plain, unit-tested types:** `NotchGeometry`, `PomodoroEngine`, `ShelfStore`,
  `ActivePlayerPicker`, and so on. Keep views thin.
- **Threading:** default isolation is MainActor. Blocking work goes in an `actor` or an async
  task; never block the main thread.

## Must-know gotchas (the full list is in docs/DEVELOPMENT.md)
- **Never hardcode the notch size;** read it from `NSScreen`.
- **Idle CPU must stay near 0%.** Be event-driven: no polling, no always-running timers.
- **Keep the Apple Development signature.** Permissions (Automation, Files) are tied to it.
- **Never trigger a permission prompt from background code.** That covers Automation and
  anything else. Only ask in response to a user action.
- **Never read another app's pasteboard contents during drag detection.**
- **App Sandbox is off, Hardened Runtime is on.** Apple Events need their entitlement and usage
  string.
- **Adding a setting:** add it to `AppSettings`, its `.all` registry, and `reload()`, plus its
  pane control.

## Conventions
- One main type per file, and the file name matches the type. Folder layout:
  `docs/BLUEPRINT.md` §9.
- Tests use Swift Testing (`import Testing`, `@Test`). New logic ships with tests.
- Log with `os.Logger` (`Log.notch`, `Log.music`, …). Never use `print`.
- **Before calling a phase done:**
  1. The build and tests pass.
  2. Walk through `docs/QA_CHECKLIST.md`.
  3. Update Status above.
  4. Ask before committing.
- **Never push, publish, or create GitHub resources without the owner's explicit go-ahead.**
