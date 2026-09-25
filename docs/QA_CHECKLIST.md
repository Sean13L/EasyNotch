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
