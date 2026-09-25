# EasyNotch

EasyNotch turns your MacBook's notch into a panel that expands when you hover over it. It will
include:

- 🎵 Music controls for Spotify and Apple Music
- 📁 A file shelf for dragging files in, dragging them back out, and sending them with AirDrop
- 🍅 A Pomodoro timer
- ⚙️ Settings to adjust size, timing, animation, and which modules appear

> **Status:** early development (Phase 0 of 6). See [docs/BLUEPRINT.md](docs/BLUEPRINT.md).

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build and run

1. Generate the Xcode project. The project file isn't committed; it's generated from `project.yml`.
   ```bash
   xcodegen generate
   ```
2. Build:
   ```bash
   xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Debug -derivedDataPath build build
   ```
3. Run:
   ```bash
   open build/Build/Products/Debug/EasyNotch.app
   ```

You can also open `EasyNotch.xcodeproj` in Xcode and press ⌘R.

EasyNotch has no Dock icon. Look for its icon in the menu bar, which has a **Quit** item.

## Docs

- [docs/BLUEPRINT.md](docs/BLUEPRINT.md): architecture, decisions, and roadmap
- [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md): beginner's guide and glossary
