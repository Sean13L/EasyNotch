# Getting Started: a beginner's guide to EasyNotch

This guide covers what you need to know to build EasyNotch with Claude Code, even if you've never
made a Mac app. The *what* and *how* of the app itself live in [`BLUEPRINT.md`](BLUEPRINT.md).

---

## 1. The big picture, in plain words

- EasyNotch is a **native macOS app**, written in **Swift**, Apple's programming language.
- The screens are built with **SwiftUI**. You describe what the UI should look like for the
  current data, and SwiftUI redraws it whenever the data changes.
- A few parts use **AppKit**, the older, lower-level Mac UI framework, for things SwiftUI can't
  do. The main one is a borderless window that floats over the menu bar.
- **Xcode** is Apple's app for writing, building, signing, and running Mac apps. Claude drives it
  from the command line; you can open the project in Xcode whenever you want to look around.
- **Your role:** decide what you want, run the app, try it, and give feedback. Claude writes the
  code, builds it, runs the tests, and explains what it did.

---

## 2. How we'll work together in Claude Code

### What is `CLAUDE.md`?

`CLAUDE.md` is a Markdown file in the project's root folder that **Claude Code reads automatically
at the start of every session**. Think of it as an onboarding note for a new teammate who forgets
everything overnight.

- **Why it exists:** every new Claude session starts with no memory of earlier chats.
  `CLAUDE.md` gives it the essentials right away: what the project is, how to build and test it,
  the rules to follow, and where things stand.
- **What goes in it:**
  - build and test commands
  - architecture rules
  - coding conventions
  - known gotchas
  - the current phase
- **What stays out:** long explanations. Those live in `docs/`, and `CLAUDE.md` points to them.
  The whole file is loaded into every session, so a bloated one wastes Claude's attention. Aim
  for under about 100 lines.
- **Where these files can live:**

  | File | Applies to |
  |---|---|
  | `~/.claude/CLAUDE.md` | You, in every project (personal preferences) |
  | `./CLAUDE.md` | This project; it's committed to git, so it's shared |
  | `some/folder/CLAUDE.md` | Loaded when Claude works inside that folder |

- **Editing it:** edit it yourself any time, or tell Claude "add to CLAUDE.md that …". The `/init`
  command generates a starter `CLAUDE.md` for an existing codebase. We wrote ours by hand because
  there's no code yet.
- **How it differs from Claude's memory:** Claude also keeps a small private memory of what it
  learns about *you* (for example, "explain things for a beginner"). `CLAUDE.md` is the project's
  shared, version-controlled rulebook; the memory is Claude's personal notebook.

### The three docs in this repo

| File | For | Purpose |
|---|---|---|
| `CLAUDE.md` | Claude | Short rules, commands, and current status |
| `docs/BLUEPRINT.md` | Both of us | Architecture, decisions, and roadmap. We update it when a decision changes |
| `docs/GETTING_STARTED.md` | You | This guide |

### The loop for each phase

1. **Kick off.** Say "Let's do Phase 1." Claude writes a detailed plan in **Plan mode** (it plans
   without touching files), and you approve it or change it.
2. **Build.** Claude writes the code, builds it from the command line, runs the tests, and fixes
   any errors.
3. **Try it.** You run the app, and Claude tells you exactly what to check.
4. **Feedback.** Tell Claude what feels off, and it adjusts.
5. **Save.** Claude asks before committing to git, then updates the status in `CLAUDE.md`.
6. **Reset.** Start a fresh session, or use `/clear`, before the next phase. `CLAUDE.md` and the
   docs carry the context forward.

### Good habits

- **Use Plan mode for anything big.** Pick it in the mode selector (Shift+Tab in the terminal
  version).
- **Git is your undo button.** Every working state gets committed, so we can always go back.
- **Give specific feedback.** "It opens too slowly and bounces too much" is far more useful than
  "it feels off." Screenshots help a lot.
- **Ask "why?" freely.** Claude can explain any line of code or any concept.
- **Review the diff before committing.** The diff shows exactly what changed.

---

## 3. One-time setup (your part of Phase 0)

Your Mac currently has only Apple's **Command Line Tools**. They can compile Swift, but they can't
build and sign a full Mac app, so you need Xcode.

1. **Install Xcode.** It's free but large (10+ GB). Open the Mac App Store, search for **Xcode**,
   click **Get**, and wait for it to finish.
2. **Open Xcode once.** Let it install its extra components, and accept the license.
3. **Point the command-line tools at Xcode.** Run these in Terminal. Each asks for your Mac
   password:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
   ```bash
   sudo xcodebuild -license accept
   ```
4. **Sign in to Xcode with your Apple ID.** A free account is fine. Go to Xcode → Settings →
   Accounts, click **+**, and choose **Apple ID**. This creates a free "Apple Development"
   certificate, which lets macOS remember the permissions you grant EasyNotch across rebuilds.
5. **Install XcodeGen:**
   ```bash
   brew install xcodegen
   ```
6. **Tell Claude "setup done."** Claude checks everything with `xcodebuild -version` and creates
   the project skeleton.

---

## 4. Concepts you'll run into (glossary)

| Term | Plain-English meaning |
|---|---|
| **Swift** | Apple's programming language |
| **SwiftUI** | UI framework where you describe the screen for a given state, and it updates automatically |
| **AppKit** | The older Mac UI framework. We use it for the notch window, mouse tracking, and AirDrop |
| **Xcode** | Apple's app for writing, building, and debugging apps |
| **`xcodebuild`** | Xcode's command-line builder. It's how Claude builds without clicking anything |
| **XcodeGen / `project.yml`** | Generates the Xcode project from one short, readable file |
| **`.app` bundle** | A Mac app is really a folder (`EasyNotch.app/Contents/…`) that Finder shows as one icon |
| **Bundle ID** | The app's unique ID, e.g. `com.seanl.easynotch`. macOS attaches permissions and settings to it |
| **Info.plist** | The app's metadata: its name, version, "hide from the Dock", and the text in permission prompts |
| **Entitlements** | Special abilities the app asks macOS for, such as "may control other apps" |
| **Code signing** | A cryptographic signature that says who built the app. macOS uses it to remember permissions |
| **Hardened Runtime / App Sandbox** | macOS security restrictions. We use Hardened Runtime and leave the sandbox off, because the sandbox gets in the way of controlling Spotify and Music |
| **TCC / privacy permissions** | The "EasyNotch wants to control Spotify" prompts, managed in System Settings → Privacy & Security |
| **Agent app (`LSUIElement`)** | An app with no Dock icon and no menu of its own; it lives in the menu bar and the notch |
| **NSPanel** | A special kind of window. Ours floats over the menu bar and never steals focus |
| **Points vs. pixels** | UI is measured in points; a Retina screen draws 2 × 2 pixels per point. Your notch is 185 × 32 pt, or 370 × 64 px |
| **`@Observable`** | Marks a class so that any view reading it refreshes when it changes |
| **Main thread / MainActor** | The thread that draws the UI. If it's blocked, the app stutters |
| **Actor** | A Swift type that safely runs work off the main thread |
| **AppleScript / Apple Events** | macOS's built-in way for one app to control another. It's how we control Spotify and Music |
| **Distributed notification** | A system-wide broadcast, such as "track changed!", that any app can listen for |
| **NSSharingService** | The macOS sharing API behind AirDrop and the Share menu |
| **UserDefaults** | Simple key-value storage for settings |
| **Unit test** | A small automated check that a piece of logic gives the right answer |
| **git / commit** | Version control. A commit is a saved snapshot of the project that you can return to |
| **Spike** | A quick, throwaway prototype that answers "does this approach even work?" before real code depends on it |

---

## 5. Debugging cheat sheet

These apply once the app exists.

- **See the app's logs:** open Console.app and search for `easynotch`, or run:
  ```bash
  /usr/bin/log stream --level debug --predicate 'subsystem == "com.seanl.easynotch"'
  ```
- **A permission is stuck or was denied:** go to System Settings → Privacy & Security → Automation
  → EasyNotch. To reset it and get the prompt again:
  ```bash
  tccutil reset AppleEvents com.seanl.easynotch
  ```
- **Quit the app:** use the menu-bar icon → Quit, or run:
  ```bash
  killall EasyNotch
  ```
- **Reset every setting to its default:**
  ```bash
  defaults delete com.seanl.easynotch
  ```
- **Build failing?** Tell Claude "the build is failing." Claude can run the build itself and read
  the error.
