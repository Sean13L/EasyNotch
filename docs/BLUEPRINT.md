# EasyNotch — Blueprint

> Architecture and system design. **Status: approved** (2026-09-25); decisions are in §13.
> Items marked ⚠️ are assumptions we prove with a small prototype (a "spike") before building
> on top of them.

---

## 1. What we're building

A native macOS utility that turns the MacBook notch into an interactive panel, like the
iPhone's Dynamic Island.

| Feature | Notch at rest | Notch expanded (on hover) |
|---|---|---|
| **Notch shell** | Invisible: a black shape exactly the size of the physical notch | Springs open into a panel with tabs |
| **Music** | Album art and a "playing" indicator beside the notch | Artwork, title/artist, play/pause, previous/next, scrubber, volume, shuffle/repeat |
| **File shelf** | Opens automatically when you drag files toward it | Drop zone; drag files back out into upload fields and apps; AirDrop; Share; Quick Look |
| **Pomodoro** | Progress ring and time left beside the notch | Start/pause/skip/reset, current phase, session count |
| **Customization** | — | Settings window: size, timing, animation, which modules show and in what order, appearance, per-feature options |

**Not in v1** (possible later): Mac App Store release, controlling browsers or other media
players (see §6.1), calendar/weather/battery widgets, and settings sync between Macs.

---

## 2. Your machine (measured 2026-09-25)

| | |
|---|---|
| Model | Mac17,2 (MacBook with a notch) |
| macOS | 27.0 (build 26A428) |
| Built-in display | 1512 × 982 pt, Retina @2x |
| **Notch** | **185 pt wide × 32 pt tall** (menu bar is 33 pt) |
| Swift | 6.4 (from Command Line Tools) |
| Xcode | ✅ 27.0 (27A266a), macOS 27.0 SDK |
| Code signing | ✅ Apple Development certificate, Personal Team `Y4Q9CP9K8V` |
| Homebrew, git, gh | ✅ installed |
| XcodeGen | ✅ 2.46.0 |

The app never hardcodes 185 × 32. It asks macOS for the notch size on every launch, so it works
on any notched MacBook. We use your numbers to test that the measurement is right.

---

## 3. Key technical decisions

| # | Topic | Choice | Why | Alternatives we rejected |
|---|---|---|---|---|
| D1 | Language & UI | **Swift 6 + SwiftUI**, with **AppKit** where needed | Native, fast, and light on battery. SwiftUI draws every view; AppKit handles the floating window, mouse tracking, and sharing | Electron/Tauri: heavy, and can't sit over the notch cleanly |
| D2 | Project file | **XcodeGen** (`project.yml` generates the `.xcodeproj`) | Xcode's own project file is a huge machine format that breaks easily. `project.yml` is about 40 readable lines that you and Claude can both edit | A hand-managed Xcode project; a Swift Package only (no SwiftUI previews, no signing UI) |
| D3 | Minimum macOS | **14 Sonoma** | Gives us `@Observable`, `SMAppService`, and modern SwiftUI, and covers every notched Mac that still gets updates | 15 or 26 (fewer Macs, and few extra APIs we'd use) |
| D4 | App type | **Agent app** (`LSUIElement`): no Dock icon, with a small menu-bar icon for Settings and Quit | A utility shouldn't clutter the Dock or ⌘-Tab | A regular app |
| D5 | Security | **App Sandbox off, Hardened Runtime on** | The sandbox blocks or complicates controlling Spotify/Music and hearing their notifications. We're not targeting the App Store | Sandbox plus "temporary exception" entitlements |
| D6 | Music integration | **AppleScript (Apple Events) for each player, plus the notifications each player broadcasts** | Officially supported, stable, and works on macOS 27 | `MediaRemote`, a private Apple framework: it works with any player, but Apple locked it down in macOS 15.4 and it now needs a hack |
| D7 | App state | **`@Observable` classes** ("services" and "stores") injected through the SwiftUI environment | Simple, modern, and needs no third-party framework | Combine/`ObservableObject` (older); TCA (too heavy for a first app) |
| D8 | Concurrency | **Main actor by default**; slow work goes in `actor`s | Removes most of Swift 6's strict concurrency errors from UI code | Annotating isolation by hand everywhere |
| D9 | Storage | **UserDefaults** for settings; **a JSON file** in Application Support for the shelf | The data is small, so no database is needed | SwiftData/Core Data (overkill) |
| D10 | Dependencies | **No third-party packages** in v1 | Less to learn, and nothing external to break | `KeyboardShortcuts` for a global hotkey may come in Phase 5 |
| D11 | Testing | **Swift Testing** (`@Test`) for logic, plus a manual QA checklist for the UI | Bugs hide in logic; UI is best checked by looking at it | XCUITest (slow and flaky for overlay windows) |
| D13 | Full-screen detection | **Undocumented `CGSManagedDisplayGetCurrentSpace` / `CGSSpaceGetType`**, looked up while the app runs | macOS has no public API for this, and window-size guesses can't tell a maximized window from a full-screen one. They're long-stable (yabai and Hammerspoon use them). If they vanish, the option simply does nothing | Window-size heuristics; dropping the option |
| D14 | Global shortcut | **Carbon `RegisterEventHotKey`** with our own recorder | Works system-wide without the Accessibility permission, and keeps zero dependencies (D10) | The `KeyboardShortcuts` package |
| D12 | Distribution | **GitHub Releases**: a zipped `.app`, not notarized, with install steps for getting past the "could not verify" warning. Releases are signed with **one stable, self-signed certificate ("EasyNotch Developer")**, so the signature carries no personal details | Free. The stable signature matters because macOS ties the Automation permission to it; with ad-hoc signing, every update would make users grant it again | Notarized Developer ID ($99/year; can be added later with no code changes); Mac App Store (needs the sandbox, see D5) |

---

## 4. Architecture overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│ APP       EasyNotchApp (@main) · AppDelegate · MenuBarMenu                 │
│           AppServices: creates and owns every service below                │
├────────────────────────────────────────────────────────────────────────────┤
│ NOTCH     ScreenManager ──► NotchWindowController (one per display)        │
│           NotchGeometry · NotchPanel · MouseTracker · NotchViewModel       │
│           NotchRootView ──► CompactView / ExpandedView + TabBar            │
├────────────────────────┬────────────────────────┬──────────────────────────┤
│ MUSIC                  │ SHELF                  │ POMODORO                 │
│ NowPlayingService      │ ShelfStore             │ PomodoroEngine           │
│ MediaPlayerSource      │ ShelfActions           │ PomodoroController       │
│ Spotify, AppleMusic    │ ShelfView              │ PomodoroView             │
│ MusicView              │ ShelfItemView          │ PomodoroCompactView      │
│ MusicCompactView       │                        │                          │
├────────────────────────┴────────────────────────┴──────────────────────────┤
│ SETTINGS  AppSettings (@Observable, saved to UserDefaults) · SettingsView  │
│ SHARED    Log · DesignTokens · small extensions                            │
└────────────────────────────────────────────────────────────────────────────┘
                                      │ talks to macOS through
                                      ▼
   NSScreen · NSEvent mouse monitors · Apple Events · DistributedNotifications
   NSSharingService (AirDrop) · UserNotifications · SMAppService (login item)
```

**Three rules keep this maintainable:**

1. **Dependencies point down only.** Views read from services; services never know about views.
2. **Features are independent.** Music, Shelf, and Pomodoro never reference each other. The notch
   layer decides which one is on screen, so adding a new feature means adding a new folder.
3. **No hidden globals.** `AppServices` creates each service once and passes it in. That makes it
   easy to swap in fake services for tests and SwiftUI previews.

### 4.1 What happens at launch

1. macOS starts `EasyNotch.app` and calls `AppDelegate.applicationDidFinishLaunching`.
2. `AppServices` is built: settings, now-playing, shelf, and pomodoro.
3. `ScreenManager` finds the displays (only the built-in one by default) and creates a
   `NotchWindowController` for each.
4. Each controller measures the notch (`NotchGeometry`), places a `NotchPanel` exactly over it, and
   puts `NotchRootView` (SwiftUI) inside.
5. `MouseTracker` starts listening for mouse movement.
6. The music sources start listening for player notifications, and Pomodoro restores any timer
   that was running when the app last quit.

### 4.2 What happens when you hover (end to end)

1. You move the mouse. macOS sends a "mouse moved" event to `MouseTracker`.
2. `MouseTracker` checks whether the pointer is inside the **hot zone** (the notch plus a few
   points of margin) and tells `NotchViewModel`.
3. `NotchViewModel` waits for the **hover delay** (default 0.15 s). If the pointer is still there,
   it sets `state = .open`.
4. `NotchWindowController` sees the change and makes the panel accept clicks.
5. `NotchRootView` sees `state == .open` and animates the black shape from 185 × 32 to the expanded
   size (default 640 × 200) with a spring, then fades the content in.
6. Once the pointer has been outside the panel for the **close delay** (default 0.15 s), everything
   runs in reverse.

---

## 5. The notch shell (the hardest part)

### 5.1 Measuring the notch: `NotchGeometry`

- `screen.safeAreaInsets.top` gives the notch height (32 pt on your Mac). A value of 0 means the
  screen has no notch.
- `screen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` give the menu-bar space on either side
  of the notch. The notch is the gap between them: width = screen width − left width − right
  width = **185 pt**, and x = screen's left edge + left width.
- Screens without a notch (external monitors, older Macs) can get an optional **virtual notch** of
  configurable size, centered in the menu bar. It's off by default.
- `NotchGeometry` is a **pure function**: screen measurements and settings go in; the rectangles
  for the closed, compact, and open states come out. We unit-test it with your real numbers.

### 5.2 The window: `NotchPanel` (a subclass of `NSPanel`) ⚠️

| Setting | Value | Effect |
|---|---|---|
| Style | Borderless, non-activating | No title bar, and clicking it never steals focus from the app you're in |
| Level | Above the main menu (about `.mainMenu + 3`) ⚠️ | Draws on top of the menu bar |
| Background | Clear, with no system shadow | Only our black SwiftUI shape is visible |
| Collection behavior | All Spaces, stationary, full-screen auxiliary, skipped by ⌘-Tab | Stays in place across desktops and full-screen apps |
| Frame | Fixed at the largest expanded size, anchored to the top-center of the notch | The window never resizes mid-animation, which keeps animations smooth |
| `ignoresMouseEvents` | `true` when closed, `false` when open | When closed, clicks pass through to the menu bar |

### 5.3 States

```
  CLOSED ◄── activity starts / ends ──► COMPACT
     │                                     │
     └──────── hover or file drag ─────────┴──►  OPEN
                                                  │
  back to COMPACT (if live) or CLOSED  ◄── leave ─┘
```

| State | Looks like |
|---|---|
| **Closed** | A black shape exactly 185 × 32, indistinguishable from the hardware notch |
| **Compact** ("live activity") | Same height, with wider "wings": album art and audio bars, or the Pomodoro ring and time. You choose which activities appear. *Arrives in Phase 2 with Pomodoro, the first feature that needs it* |
| **Open** | The expanded panel (default 640 × 200 pt, adjustable) with a tab bar for the enabled modules |

| From | Event | To |
|---|---|---|
| Closed | Music starts playing or a timer starts | Compact |
| Compact | Music stops and the timer is idle | Closed |
| Closed or compact | Pointer stays in the hot zone for the hover delay (or you click it, in click mode) | Open |
| Closed or compact | Files are dragged near the notch | Open, on the Shelf tab |
| Open | Pointer leaves for the close delay, or you click elsewhere | Compact if an activity is live, otherwise Closed |

### 5.4 Hover detection: `MouseTracker`

- While closed, the panel ignores the mouse, so SwiftUI's `.onHover` can't see it. Instead we
  listen to system-wide mouse-move events with `NSEvent.addGlobalMonitorForEvents` plus a local
  monitor. Watching **mouse** events doesn't need the Accessibility permission; only keyboard
  monitoring would.
- The hot zone is the notch plus a configurable margin, so it's easy to hit.
- It is event-driven with no polling, so CPU use is about 0% while idle.
- **Drag detection:** it watches `leftMouseDragged` and checks the system drag pasteboard for
  file URLs. If files are being dragged near the notch, it opens straight to the Shelf.

### 5.5 Animation and feel

- **SwiftUI springs**, with presets (Smooth, Snappy, Bouncy) or custom response and damping.
- **`NotchShape`** draws rounded bottom corners and small concave "ears" where the shape meets
  the top of the screen. The corner radii animate along with the size.
- An optional **haptic tick** on open, felt on a Force Touch trackpad.
- The content fades and un-blurs slightly after the shape starts growing, the way Dynamic Island
  does.

### 5.6 Multiple displays and system events

- By default only the built-in display gets a notch. You can also pick all displays or the main
  display; screens without a notch get the virtual notch.
- The windows are rebuilt on `NSApplication.didChangeScreenParametersNotification`, which fires
  when you plug or unplug a display, change resolution, or close the lid.
- We handle sleep/wake, switching Spaces, and full-screen apps. An option hides the notch while a
  full-screen app is in front.

---

## 6. Feature modules

Each feature has the same parts:
- **logic** that is testable and has no UI
- an **expanded view**
- an optional **compact view** for the live activity
- a **settings pane**

The modules are listed in one `enum NotchModule { music, shelf, pomodoro }`, which drives the
tab bar, the enable/disable toggles, and tab order. Adding a module means adding one case and one
folder.

### 6.1 Music (Spotify and Apple Music)

```
  Spotify.app                             Music.app
    │         ▲                             │         ▲
    │ notify  │ AppleScript                 │ notify  │ AppleScript
    │ (free)  │ commands                    │ (free)  │ commands
    ▼         │                             ▼         │
  MediaPlayerSource + Spotify.profile     MediaPlayerSource + AppleMusic.profile
        │                                         │
        └────────────────────┬────────────────────┘
                             ▼
                     NowPlayingService    ← picks the active player
                             ▼
                 MusicView  ·  MusicCompactView
```

**Each player has two channels:**

1. **Listening.** Spotify and Music broadcast a system-wide notification whenever the track or
   play state changes (`com.spotify.client.PlaybackStateChanged` and `com.apple.Music.playerInfo`).
   This is instant and needs no permission.
2. **Commanding.** AppleScript handles play/pause, next/previous, seek, volume, shuffle/repeat,
   and fetching the artwork. The first time, macOS asks you once per player: *"EasyNotch wants
   to control Spotify."*

**How it works:**

- **One engine, two profiles.** `MediaPlayerSource` does the listening, asking, and artwork
  loading. Everything app-specific lives in a `PlayerProfile`:
  - the bundle ID and notification name
  - the AppleScript
  - how to read the replies

  `Spotify.swift` and `AppleMusic.swift` each hold one profile, so supporting another scriptable
  player means writing one new file.
- **Never prompts on its own.** macOS's `AEDeterminePermissionToAutomateTarget` checks the
  permission *without* asking. Background refreshes use AppleScript only once permission is
  already granted. The prompt appears only when you press a control or **Allow…**. Until then,
  titles and progress come from the broadcasts.
- **Broadcasts are delivered immediately.** macOS normally holds another app's notifications
  until the receiving app is active, which an agent app rarely is. `DistributedNotificationObserver`
  asks for immediate delivery.
- **Progress bar without polling.** We store the position, a timestamp, and whether it's playing.
  The view computes the elapsed time live.
- **No accidental launches.** We only talk to a player if `NSRunningApplication` says it's
  running, because sending it a command would launch it.
- **Choosing the active player** (`ActivePlayerPicker`, unit-tested), in order:
  1. a player you switched to by hand, until another one starts playing
  2. the one that's playing (your preferred one if both are, otherwise the latest to start)
  3. your preferred player
  4. the most recently active one
- **`AppleScriptRunner` actor.** It runs on its own serial queue, so a slow player or a
  waiting prompt never blocks anything else. It caches compiled scripts, sets a 3-second timeout
  in every script, and turns error codes into clear states. For example, `-1743` (not
  authorized) shows an "Open System Settings" button.
- **Compact view.** Album art in the left wing, and four bouncing equalizer bars in the
  player's color in the right. The bars run on Core Animation, so they cost no app CPU, and each
  follows its own pattern and speed. They're decorative; real audio levels would need the Screen
  Recording permission, which isn't worth it. A running Pomodoro takes priority over music for
  the wings.
- **Paused music lingers.** After a track that was playing is paused, its wings stay up
  (bars at rest) for a duration you choose (`PausedTrackLinger`, tested), then hide.
- **Layout.** Shuffle · previous · play · next · repeat sit centered under the progress bar.
  Volume sits in the header row.
- **Expanded view.** Artwork, title, artist, album, scrubber, previous/play/next, volume,
  shuffle/repeat, "open in app", and a player switcher.
- **Why not every player (browsers, Podcasts, and so on).** That needs Apple's private
  `MediaRemote` framework, which has been locked down since macOS 15.4. We may revisit it later
  as an experimental source.

### 6.2 File shelf and AirDrop

**Flow:**

1. Drag files toward the notch. It opens on the Shelf tab and the drop zone lights up.
2. Drop them. They appear as thumbnails, generated by Quick Look.
3. Later, drag one or more items **out** into a browser upload field, Slack, Mail, Finder, and so
   on.
4. Or use the actions: **AirDrop**, Share…, Quick Look, Copy, Reveal in Finder, Open, Remove,
   Clear all.
5. Dropping files on the dedicated **AirDrop tile** opens the macOS AirDrop picker right away.

**Design:**

- `ShelfItem { id, bookmark, name, addedAt }` stores a **bookmark** rather than a plain path, so
  the item survives the file being renamed or moved.
- `ShelfStore` (`@Observable`) saves to `~/Library/Application Support/EasyNotch/shelf.json`,
  removes duplicates, caps the number of items, and can auto-clear after N days.
- **AirDrop, Share, Quick Look.** `ShelfActions` handles them:
  - AirDrop uses `NSSharingService(named: .sendViaAirDrop)`.
  - The Share menu is SwiftUI's `ShareLink`.
  - Quick Look uses `QLPreviewPanel`.

  Each activates the app first, because agent apps are never active on their own.
- **Spotting a file drag while the notch is closed.** `MouseTracker` watches drags system-wide.
  `FileDragDetector` (tested) compares the drag pasteboard's change counter with its value at
  mouse-down, then checks only the pasteboard's list of *types*, never its contents. A file
  drag near the notch opens it instantly on the Shelf tab. Moving windows and selecting text
  never open it.
- **Dragging out.** Tiles and the drag-all handle use AppKit drag sessions
  (`FileDragSource.swift`), because SwiftUI's own dragging can't say whether a drop happened.
  The tiles are started from a SwiftUI drag gesture through an invisible `FileDragAnchor`.
  Dragging a selected tile carries the whole selection. With "Remove files after dragging them
  out" on (off by default), files leave the shelf once dropped somewhere other than the notch.
- **Protected folders** (decided: keep links, ask once). macOS asks once per protected folder
  (Downloads, Desktop, Documents) before EasyNotch can reopen files there. If access is denied,
  tiles show **No access** rather than "Missing", with a shortcut to System Settings → Files &
  Folders. The store tells the two apart by whether reading the file's details is refused.
- If a file has been deleted since you added it, its item is greyed out and offers "Remove".
- **Later:** text snippets and links, images dragged from browsers ("file promises"), and a mode
  that copies files into the shelf.

### 6.3 Pomodoro

`PomodoroEngine` is a **pure-logic state machine** with no timers inside, so it's fully
unit-tested:

```
 idle ──start──► FOCUS 25m ──done──► SHORT BREAK 5m ──done──► FOCUS …
                     │
                     └── after every 4th focus ──► LONG BREAK 15m ──done──► FOCUS …

 Anytime: pause / resume · skip → next phase · reset → idle
```

- **It stores the end time (`endsAt`), not a countdown.** That keeps it accurate through sleep,
  heavy load, and even an app relaunch.
- **`PomodoroController` (`@Observable`) runs the engine.**
  - It ticks the UI once per second, only while running.
  - It schedules a macOS notification for `endsAt`, which fires even if the app is busy.
  - It plays a sound when a phase ends.
  - It can optionally start the next phase automatically.
- **Compact view:** a progress ring and `12:34` in the right wing.
- **Expanded view:** a large timer, the phase name, session dots (●●○○), start/pause/skip/reset,
  and quick presets.
- **Settings:** durations, sessions before a long break, auto-start for breaks and focus, sounds,
  and whether it shows in the compact notch.
- **Nice to have:** a count of sessions completed today.

### 6.4 Customization: `AppSettings`

A single `@Observable` settings object. Every option has a default and is saved to UserDefaults
the moment it changes, and the notch updates live as you adjust it.

| Group | Options |
|---|---|
| Behavior | Open on hover or click; hover delay; close delay; hot-zone size; open on file drag; haptics; hide in full-screen apps |
| Size & shape | Expanded width and height (minimum 560×190 pt, so every tab fits); corner radius; compact wing width (0 = exactly the notch's size); live preview of either shape in the Size pane |
| Animation | A preset (Smooth, Snappy, Bouncy) or a custom spring |
| Modules | Turn Music, Shelf, and Pomodoro on or off; drag to reorder tabs; default tab; which live activities appear in compact mode |
| Appearance | Accent color; background (pure black to match the hardware, or blur); tab labels on or off |
| Displays | Built-in only, all, or main display; virtual notch size for screens without a notch |
| Music | Preferred player; album art in compact mode |
| Shelf | Maximum items; auto-clear; confirm before clearing |
| Pomodoro | Durations; cycles; auto-start; sounds; notifications |
| General | Launch at login; global keyboard shortcut (Phase 5); reset to defaults; export and import settings |

**Built in Phase 5:** General (launch at login, keyboard shortcut, export/import), Behavior (open
by hover or click, hide in full screen, right-click menu), Appearance (animation presets, accent
color), Displays (built-in / main / all, virtual notch), and Modules (reorder, hide, opening tab).
**Dropped on purpose:** a blurred background, because the hardware notch is pure black and any
see-through area would leave a visible seam, and tab text labels, which don't fit beside the
notch at small sizes.

The Settings window has a sidebar with one pane per group, and **Restore Defaults…** sits at
the bottom of the sidebar. You can open it from the menu-bar icon, from the gear in the
expanded notch, or by right-clicking the notch (Phase 5). While the Size pane is showing and the
window is in front, the notch stays open as a live preview.

---

## 7. Data and persistence

| Data | Owned by | Stored in |
|---|---|---|
| Settings | `AppSettings` | UserDefaults (the app's bundle-ID domain) |
| Shelf items | `ShelfStore` | `~/Library/Application Support/EasyNotch/shelf.json` |
| Running Pomodoro | `PomodoroController` | UserDefaults (the phase and `endsAt`) |
| Now playing | `NowPlayingService` | Memory only; re-read from the players |
| Launch at login | macOS (`SMAppService`) | The system; we only read and toggle it |

---

## 8. Permissions and entitlements

| Permission | Why we need it | When macOS asks |
|---|---|---|
| Automation → Spotify | Play/pause, next, artwork | The first time you use a Spotify control |
| Automation → Music | The same, for Apple Music | The first time you use a Music control |
| Notifications | Pomodoro alerts | The first time you start a timer |
| *(none)* | Hover tracking, drag and drop, AirDrop | Never |

**Configuration files:**

- **`Info.plist`**
  - `LSUIElement = YES` (no Dock icon)
  - `NSAppleEventsUsageDescription` (the text shown in the Automation prompt)
- **`EasyNotch.entitlements`**
  - `com.apple.security.automation.apple-events = YES`
  - no sandbox

**Signing tip:** macOS ties these permissions to the app's code signature. We'll sign with your
free "Apple Development" certificate so you aren't asked again after every build.

---

## 9. Project structure

```
EasyNotch/
├── CLAUDE.md                 ← instructions Claude Code reads every session
├── README.md                 ← what the app is and how to build it (Phase 0)
├── project.yml               ← XcodeGen spec: the source of truth for the Xcode project
├── .gitignore                ← ignores EasyNotch.xcodeproj, build/, .DS_Store
├── docs/
│   ├── BLUEPRINT.md          ← this file
│   ├── GETTING_STARTED.md    ← beginner guide and setup
│   └── QA_CHECKLIST.md       ← manual test script (starts in Phase 1)
├── EasyNotch/
│   ├── App/                  EasyNotchApp, AppDelegate, AppServices, MenuBarMenu
│   ├── Notch/                NotchGeometry, NotchPanel, NotchWindowController,
│   │   │                     ScreenManager, MouseTracker, NotchViewModel, NotchModule
│   │   └── Views/            NotchRootView, NotchShape, CompactView, ExpandedView, TabBar
│   ├── Features/
│   │   ├── Music/            PlayerProfile, PlayerSnapshot, Spotify, AppleMusic,
│   │   │                     AppleScriptRunner, MediaPlayerSource, ActivePlayerPicker,
│   │   │                     NowPlayingService, MusicView, MusicCompactView, MusicArtwork
│   │   ├── Shelf/            ShelfItem, ShelfStore, ShelfThumbnails, ShelfActions,
│   │   │                     ShelfView, ShelfItemView, FileDragSource
│   │   └── Pomodoro/         PomodoroEngine, PomodoroController, PomodoroView,
│   │                         PomodoroCompactView
│   ├── Settings/             AppSettings, SettingsWindowController, SettingsView,
│   │                         ShortcutRecorder, Panes/ (General, Behavior, Appearance, Size,
│   │                         Displays, Modules, Music, Shelf, Pomodoro)
│   ├── Shared/               Log, NotchAccent, HotKeyCenter, FullScreenDetector, LoginItem,
│   │                         DistributedNotificationObserver, SecondsTimeline, extensions
│   └── Resources/            Assets.xcassets, Info.plist, EasyNotch.entitlements
└── EasyNotchTests/           NotchGeometryTests, PomodoroEngineTests, ShelfStoreTests,
                              NowPlayingServiceTests (using fake players)
```

---

## 10. Quality bar

- **Performance:**
  - about 0% CPU while the notch is closed and nothing is playing
  - under 80 MB of memory
  - smooth animation at 120 Hz on ProMotion displays
- **Tests:** every pure-logic type has unit tests, and `xcodebuild test` passes before a phase
  counts as done.
- **Manual QA:** walk through `docs/QA_CHECKLIST.md` after each phase:
  - hover and click-through
  - Spaces and full-screen apps
  - plugging and unplugging a display
  - sleep and wake
  - what happens when a permission is denied
- **Logging:** `os.Logger` with one category per area (notch, music, shelf, pomodoro). You can
  watch it live in Console.app.
- **Graceful failure:** a missing permission, a player that isn't running, or a deleted file shows
  a friendly message in the UI and never crashes the app.

---

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Window level, click-through, or Spaces behave differently on macOS 27 ⚠️ | High | Phase 1 opens with a spike that proves this before anything else is built |
| The hot zone gets in the way of menu-bar items beside the notch | Medium | A small hot zone and a hover delay, both configurable |
| macOS asks for the Automation permission again after every build | Medium | A stable signing identity (Apple Development) |
| Spotify changes its AppleScript commands | Medium | Contained in `Spotify.swift`; errors fall back to "controls unavailable" |
| Drag detection misses some drag sources | Low | You can always open the notch first, then drop |
| Swift 6 concurrency errors are confusing | Low | Main actor by default, and Claude explains any error that appears |

---

## 12. Roadmap

Every phase ends the same way:
1. It builds cleanly and the tests pass.
2. You try it.
3. We update the status in `CLAUDE.md`.
4. We commit, after your OK.

| Phase | Goal | Done when… | Size |
|---|---|---|---|
| **0. Setup** | Tools and an empty app | Xcode and XcodeGen are installed; git is set up; the app builds from the command line and shows a menu-bar icon with Quit, and no Dock icon | S |
| **1. Notch shell** | The core window | See the list below | L |
| **2. Pomodoro** ✅ | First real module (no permissions, pure logic); also adds the compact live-activity state. Defaults: breaks start automatically, focus waits for Start | The full focus → break → long-break cycle works; pause/skip/reset work; a notification and sound play at the end; timing stays accurate after sleep; the compact ring shows; settings pane; engine unit tests | M |
| **3. Music** ✅ | Spotify and Apple Music | The right track and artwork appear within 1 s of a change; every control works in both players; a denied permission is explained; a player is never launched by accident; compact live activity; settings pane | L |
| **4. Shelf + AirDrop** ✅ | Quick file access | Dragging in opens the shelf; dragging out works into Finder, browser upload fields, Slack, and Mail; AirDrop tile plus per-item AirDrop, Share, and Quick Look; items survive a relaunch; missing files are handled | M |
| **5. Customization** ✅ | Everything is adjustable | Every option in §6.4 works live; module toggles and reordering; animation presets; display options; launch at login; global shortcut; reset, export, and import | M |
| **6. Polish & ship** ✅ | Good enough for daily use | App icon; a performance pass with Instruments; the full QA checklist; a Release build installed in /Applications; a signed `.zip` on GitHub Releases with install instructions (D12); a license and a public repo | S–M |

**Phase 1 is done when:**
- the closed notch is invisible on your screen (pixel-matched to 185 × 32)
- hovering springs it open to a placeholder panel with tabs
- moving away closes it
- menu-bar items beside the notch are still clickable
- it works on every Space and over full-screen apps
- it survives plugging and unplugging a display
- a basic Settings window has Behavior and Size panes

**Why this order:**
- **Notch shell first.** It's the riskiest part, and everything depends on it.
- **Pomodoro next.** It's self-contained, and it sets the pattern that later modules and compact
  activities follow.
- **Then Music**, which adds permissions.
- **Then Shelf**, which adds drag and drop.
- **Customization last**, layered on once the features exist. Each earlier phase still adds its
  own settings pane.

---

## 13. Decisions made (2026-09-25)

You approved the recommended defaults, plus GitHub Releases for distribution.

| # | Decision | Choice |
|---|---|---|
| 1 | Minimum macOS | 14 Sonoma |
| 2 | Distribution | Free download from **GitHub Releases**, not notarized for now (D12). Notarizing ($99/year) can come later without code changes |
| 3 | Bundle ID | `com.seanl.easynotch` |
| 4 | Other displays | Built-in notch only by default; the virtual notch is an opt-in setting |
| 5 | Default open behavior | Hover (click is an option) |
| 6 | Shelf | Keeps links (bookmarks) to the original files |
| 7 | Music scope | Spotify and Apple Music; "any player" support is a possible later experiment |
