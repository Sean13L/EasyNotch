# QA Checklist

A hands-on test script. After each phase, walk through that phase's section and skim the earlier
ones to catch anything that broke.

Before you start, quit any running copy (menu-bar icon → Quit) and launch the latest build (see
the README).

---

## Phase 1: Notch shell

### While closed
- [ ] With the pointer away from the notch, the notch looks untouched. There are no black specks
      around its bottom corners.
- [ ] Menu-bar icons right next to the notch, on both sides, still respond to clicks.
- [ ] CPU use is about 0%. Check with:
      `top -l 2 -pid $(pgrep -x EasyNotch) -stats cpu`

### Opening and closing
- [ ] Resting the pointer on the notch opens it after the hover delay. Sweeping quickly past it
      does not.
- [ ] It opens even when another app is in front, and it doesn't steal focus: your typing still
      goes to that app.
- [ ] Each tab icon switches on the first click.
- [ ] The gear opens Settings and closes the notch.
- [ ] Moving the pointer away closes the notch after the close delay.
- [ ] Clicking anywhere else closes it right away.

### Everywhere
- [ ] It works on every desktop (Space) and over a full-screen app.
- [ ] Unplugging and re-plugging an external display leaves the notch working on the built-in
      screen.
- [ ] Closing the lid while an external display is attached, then reopening it, leaves the notch
      working.
- [ ] After sleep and wake, the notch still works.

### Settings
- [ ] Menu-bar icon → **Settings…** opens the window in front of other apps. ⌘, works while that
      menu is open.
- [ ] The **Behavior** sliders change the hover delay, close delay, and hover area immediately.
- [ ] The haptic toggle works: you feel a tap on open only when it's on, while touching the
      trackpad.
- [ ] While the **Size** pane is showing, the notch stays open and resizes live as you drag.
      Switching to another pane or another app lets it close.
- [ ] **Restore Defaults…** asks for confirmation first, then resets everything.
- [ ] Quit and relaunch: your settings are kept.
- [ ] ⌘W closes the Settings window.

---

## Phase 2: Pomodoro and the compact notch

**Tip:** for quick testing, set Focus and Short break to 1 minute in Settings → Pomodoro.
Restore them afterwards.

### The Pomodoro tab
- [ ] Hover the notch and pick the timer tab. It shows a ring with `25:00`, "Focus", "Ready", four
      empty dots, and "Today: 0 sessions".
- [ ] **Start:** the ring fills and the time counts down every second. The button becomes Pause.
- [ ] **Pause:** the countdown stops and "Paused" appears. **Resume** continues from the same
      time.
- [ ] **Skip:** jumps to the break (no sound) and fills one dot.
- [ ] **Reset:** back to `25:00` Focus with empty dots.

### The compact notch (live activity)
- [ ] While a timer runs, the closed notch shows a small ring on the left and the time on the
      right. The wings line up flush with the notch.
- [ ] While paused, the ring shows a pause symbol and the time turns grey.
- [ ] Hovering either wing opens the notch straight to the timer tab.
- [ ] After Reset, the wings disappear.
- [ ] Turning off Settings → Pomodoro → "Show the timer beside the notch" hides the wings.
- [ ] Settings → Size → "Live activity width" changes how wide the wings are.

### When a phase ends
- [ ] The first Start asks for notification permission. Allow it.
- [ ] At the end of a focus session:
  - [ ] the chosen sound plays
  - [ ] a notification appears ("Focus session complete…")
  - [ ] the break starts by itself (default)
  - [ ] a dot fills
  - [ ] "Today" goes up by one
- [ ] At the end of a break, the next focus waits for Start (default).
- [ ] After the 4th focus session comes a long break (blue), with all four dots filled.
- [ ] The auto-start toggles in Settings change both behaviors.
- [ ] Picking a sound in Settings plays a preview. Turning "Play a sound" off silences the end
      of a phase.

### Robustness
- [ ] Put the Mac to sleep mid-session for longer than the time left. On wake, the phase has
      finished and the next one has started from the wake time.
- [ ] Quit EasyNotch mid-session and reopen it: the timer is still running with the correct time.
- [ ] Changing the focus length mid-session doesn't change the running timer, only the next one.

---

## Phase 3: Music (Spotify and Apple Music)

**Before you start:** sign in to Xcode with your Apple ID (Xcode → Settings → Accounts) and tell
Claude, so the app gets a stable signature. Until then, macOS may ask for permission again after
every rebuild.

### Without permission (nothing has been allowed yet)
- [ ] With Spotify open but not playing, the Music tab says "Spotify is open" and shows an
      **Allow…** hint. No permission prompt appears on its own.
- [ ] Press play in Spotify itself. Within about a second, the tab shows the title, artist,
      album, and a moving progress bar, still without any prompt.
- [ ] The closed notch shows the music wings (a cover placeholder on the left, a pulsing
      waveform on the right). Hovering them opens the Music tab.

### Granting permission
- [ ] Press **Allow…** (or any control button). macOS asks: "EasyNotch wants to control
      Spotify". Choose Allow.
- [ ] Cover art appears. The volume slider and the shuffle and repeat buttons appear.
- [ ] Do the same for the Music app.
- [ ] Settings → Music shows each player's status (Allowed / Not asked yet / Not allowed).

### Controls (for each player)
- [ ] Play/pause responds instantly and matches the app.
- [ ] Next and previous change the track; the title and cover art update.
- [ ] Dragging the progress bar seeks.
- [ ] The volume slider changes the app's volume.
- [ ] Shuffle toggles. Repeat cycles off → all → one (Music) or on/off (Spotify).
- [ ] The app icon (top right) opens the player.

### Several players
- [ ] With Spotify and Music both open, the one that's playing is shown. The other player's
      faded icon switches to it.
- [ ] Settings → Music → "When several players are open, show" picks a favorite.
- [ ] A running Pomodoro timer takes the wings over music; a paused one gives them back.

### Edge cases
- [ ] Quit the player: the tab shows "Nothing playing" with **Open Spotify / Open Music** buttons,
      and the wings disappear.
- [ ] Deny permission (or turn it off in System Settings → Privacy & Security → Automation). The
      tab explains this and offers **Open System Settings**. Titles from broadcasts still appear.
- [ ] EasyNotch never launches a player by itself, except when you press Play with it closed.
- [ ] CPU stays around 0% while music plays and the notch is closed.
