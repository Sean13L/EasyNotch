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
- [ ] At the smallest width and height (560 × 190), check the Music and Pomodoro tabs: nothing
      overlaps or gets cut off.
- [ ] Dragging **Live activity width** switches the preview to the closed notch with its wings.
      Faint bars show the wing size when nothing is playing or timing. Dragging Width or Height
      switches back to the open notch.
- [ ] Live activity width goes down to 0, where the closed notch is exactly the hardware notch.
      In narrow wings the content shrinks and never spills outside them.
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
- [ ] The closed notch shows the music wings: a cover placeholder on the left, and bars on the
      right that bounce independently while playing and settle smoothly when paused. Hovering
      them opens the Music tab.

### Granting permission
- [ ] Press **Allow…** (or any control button). macOS asks: "EasyNotch wants to control
      Spotify". Choose Allow.
- [ ] Cover art appears. The volume slider and the shuffle and repeat buttons appear.
- [ ] Do the same for the Music app.
- [ ] Settings → Music shows each player's status (Allowed / Not asked yet / Not allowed).

### Controls (for each player)
- [ ] The play button sits exactly under the middle of the progress bar, with shuffle and repeat
      on either side and volume at the top right.
- [ ] Play/pause responds instantly and matches the app.
- [ ] Next and previous change the track; the title and cover art update.
- [ ] Dragging the progress bar seeks.
- [ ] The volume slider changes the app's volume.
- [ ] Shuffle toggles. Repeat cycles off → all → one (Music) or on/off (Spotify).
- [ ] The app icon (top right) opens the player.

- [ ] Pause the music. The wings stay up with the cover art and resting bars for the time set
      in Settings → Music → "After pausing, keep showing it for", then disappear. Resuming
      brings the moving bars back.

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

---

## Phase 4: File shelf and AirDrop

### Dragging files in
- [ ] Drag a file from Finder toward the notch. The notch opens right away on the Shelf tab,
      even with a long hover delay. No clipboard or privacy prompt appears.
- [ ] Drop anywhere on the open notch. The file appears as a thumbnail. Drop several files at
      once, and a folder. The newest go first; dropping a file that's already there moves it to
      the front.
- [ ] Dragging a window, or selecting text near the top of the screen, never opens the notch.
- [ ] Settings → Shelf → "Open the notch when dragging files near it" off: dragging no longer
      opens it, but hovering first and then dropping still works.

### Using the files
- [ ] Drag a tile out into Finder, a browser upload field (Gmail or Google Drive), Slack, and
      Mail. The notch may close behind you; the drop should still work.
- [ ] Click to select a tile, ⌘-click to select several. The drag-all handle (stack icon)
      drags the selection, or everything if nothing is selected.
- [ ] Double-click opens the file.
- [ ] Right-click → Open, Quick Look, Show in Finder, Copy (then ⌘V in Finder), AirDrop,
      Share…, Remove from Shelf. With several selected, each acts on all of them.
- [ ] The header's Share and Copy buttons work.
- [ ] The trash button asks "Clear all?" first. Click again to clear. It resets on its own after
      3 s.
- [ ] Settings → Shelf → "Remove files after dragging them out":
  - [ ] Off (default): dragged-out files stay on the shelf.
  - [ ] On: a file dropped into Finder or an upload field leaves the shelf. Dropping it back
        onto the notch, or cancelling the drag, keeps it.

### AirDrop
- [ ] Drop files onto the AirDrop tile. The AirDrop picker opens right away and you can send
      them to your phone.
- [ ] Clicking the tile AirDrops the selected files (or all of them).

### Keeping track of files
- [ ] Quit and reopen EasyNotch: the shelf is unchanged.
- [ ] Rename a shelf file in Finder: the tile shows the new name the next time the tab opens.
- [ ] Delete a shelf file (empty the Trash, or just move it to the Trash): its tile dims and
      says "Missing", and right-click offers only Remove.
- [ ] The first file from Downloads, Desktop, or Documents triggers one macOS prompt per folder.
      Allow it, and it never asks again, even after a rebuild.
- [ ] If access is turned off (System Settings → Privacy & Security → Files & Folders →
      EasyNotch), those files show "No access" with a lock. Right-click → "Allow Access in
      System Settings…" opens that page. Settings → Shelf has the same button.
- [ ] "Keep at most" limits the number of files (the oldest drop off). "Remove files
      automatically" removes old ones.

---

## Phase 5: Customization

### General
- [ ] **Open EasyNotch when you log in:** turn it on, restart the Mac, and EasyNotch starts by
      itself. If macOS asks, allow it in System Settings → General → Login Items; the pane
      shows a button for that.
- [ ] **Keyboard shortcut:**
  - [ ] Click "Record Shortcut" and press e.g. ⌥⌘N. It shows "⌥⌘N". A letter without ⌘, ⌥, or
        ⌃ just beeps; Esc cancels; Delete clears.
  - [ ] From any app, the shortcut opens the notch on the screen with the pointer.
  - [ ] The notch stays open until you press it again, click elsewhere, or move the pointer in
        and back out.
- [ ] **Export Settings…** saves a `.json` file. Change a few options, **Import Settings…** that
      file, and they come back. Importing a random file shows a friendly message.

### Behavior
- [ ] **Open the notch by: Clicking it.** Hovering no longer opens it; a click on the notch
      does. Moving away or clicking elsewhere still closes it.
- [ ] **Right-click the closed notch:** a menu with Settings… and Quit EasyNotch appears.
- [ ] **Hide the notch while an app is full screen:** make a video or app full screen. The notch
      disappears on that screen and comes back when you leave full screen.

### Appearance
- [ ] Each animation style (Snappy, Smooth, Bouncy, Minimal) feels different when opening and
      closing.
- [ ] With macOS Accessibility → Display → "Reduce motion" on, the notch uses Minimal, and the
      pane says so.
- [ ] The "System" swatch shows your macOS accent color (blue on your Mac), not grey.
- [ ] Pick an accent color: the selected tab, selected shelf files, and the AirDrop drop
      highlight use it. "System" looks the same as before.

### Displays (plug in your external monitor)
- [ ] "All screens": the external monitor gets a black virtual notch at the top center, as tall
      as its menu bar. Hover opens it just like the real one, and every tab works there.
- [ ] The virtual notch's width slider changes it live.
- [ ] "The main screen" and "This Mac's own screen" put the notch only where they say.

### Modules
- [ ] Reorder tabs by dragging a row onto another (it highlights) or with the arrows; the notch's
      tab bar follows.
- [ ] Turn a tab off:
  - [ ] it disappears from the notch
  - [ ] Music off: no music wings
  - [ ] Pomodoro off: no timer wings
  - [ ] Shelf off: dragging files no longer opens the notch
- [ ] The last tab that's on can't be turned off.
- [ ] "Tab that opens first" picks the tab shown on hover. A running timer, playing music, or a
      file drag still opens its own tab.

### Everything together
- [ ] **Restore Defaults…** puts every option back, including tab order, displays, and the
      shortcut.
- [ ] CPU stays about 0% while idle.

---

## Phase 6: Release build (the copy in /Applications)
- [ ] EasyNotch runs from /Applications, and the new icon shows in Finder and Launchpad.
- [ ] Music: allow "EasyNotch wants to control Spotify/Music" once more; the release is signed
      differently from the development builds. The controls work.
- [ ] Shelf: files from Downloads and other protected folders open (allow access once if
      asked).
- [ ] Settings → General → "Open EasyNotch when you log in": turn it off and on again, then
      restart. The /Applications copy starts by itself.
- [ ] Walk through the earlier phases' checks you haven't confirmed yet.

---

## v1.1: Next Meeting, Battery & Charging, System Monitor

### Tabs
- [ ] Six tabs fit at the smallest notch size (Settings → Size): three sit left of the notch
      and three right, before the gear.
- [ ] Turn tabs off until 3 or fewer are on: they all move back to the left, like in v1.0.
- [ ] Settings → Modules lists the new tabs at the end, and you can reorder and hide them.

### Next Meeting (Calendar tab)
- [ ] Before allowing access, the tab shows **Allow Calendar Access**. No prompt appears until
      you press it.
- [ ] Press it and choose Allow: today's meetings appear.
- [ ] Declining instead shows "Calendar access is turned off". **Open System Settings** opens
      Privacy & Security → Calendars.
- [ ] A meeting with a Zoom, Meet, Teams, Webex, or FaceTime link has a **Join** button, and
      it opens the call.
- [ ] Meetings you've declined don't appear.
- [ ] Settings → Calendar:
  - [ ] "List all-day events" hides or shows them.
  - [ ] Unticking a calendar removes its events.
- [ ] Beside the notch (make a test event starting in a few minutes):
  - [ ] from your lead time (default 5 minutes), a colored dot and "4m" appear
  - [ ] "now" appears at the start time
  - [ ] they disappear 5 minutes after the start
  - [ ] hovering opens the Calendar tab
- [ ] Moving or deleting the test event in Calendar updates the notch within a few seconds.

### Battery & Charging
- [ ] The Battery tab's percentage and status match the battery menu in the menu bar, including
      "holding at 80%" when macOS pauses charging.
- [ ] The tab shows the charger's watts, battery health, and cycle count. Compare them with
      System Settings → Battery → ⓘ.
- [ ] Plug in the charger: a bolt and the percentage flash beside the notch for about
      4 seconds.
- [ ] Unplug: no flash.
- [ ] Turning Low Power Mode on or off shows in the tab straight away.
- [ ] Settings → Battery: turning off "Flash the charge when you plug in" stops the flash.
- [ ] Low battery: when the battery is at or below the threshold and unplugged, a red battery
      shows beside the notch. Plugging in removes it. You can only check this when the battery
      is actually low.

### System Monitor
- [ ] The System tab shows CPU and memory close to Activity Monitor's figures. The charts fill
      in over time.
- [ ] Download speed rises while you download something big.
- [ ] Free disk space matches Finder's "available" figure.
- [ ] Settings → System → "Show big downloads and uploads beside the notch":
  - [ ] with it on, a large download shows "↓ 12 MB/s" beside the notch after a couple of
        seconds
  - [ ] the speed disappears soon after the download ends

### Priorities and cost
- [ ] With music playing, plugging in the charger shows the flash first, then music comes
      back.
- [ ] A meeting about to start wins over a running timer or music.
- [ ] Hidden tabs never show anything beside the notch.
- [ ] CPU stays about 0% while idle with nothing playing and the System tab closed.
