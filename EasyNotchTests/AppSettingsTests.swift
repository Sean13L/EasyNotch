import Foundation
import Testing
@testable import EasyNotch

struct AppSettingsTests {
    @Test func freshInstallUsesDefaults() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            #expect(settings.hoverDelay == 0.15)
            #expect(settings.closeDelay == 0.15)
            #expect(settings.hotZoneMargin == 8)
            #expect(settings.hapticsEnabled)
            #expect(settings.expandedWidth == 640)
            #expect(settings.expandedHeight == 200)
            #expect(settings.compactWingWidth == 64)
            #expect(settings.focusMinutes == 25)
            #expect(settings.shortBreakMinutes == 5)
            #expect(settings.longBreakMinutes == 15)
            #expect(settings.sessionsBeforeLongBreak == 4)
            #expect(settings.autoStartBreaks)
            #expect(!settings.autoStartFocus)
            #expect(settings.pomodoroInNotch)
            #expect(settings.pomodoroNotifications)
            #expect(settings.pomodoroSoundEnabled)
            #expect(settings.pomodoroSound == "Glass")
            #expect(settings.musicPausedLinger == 60)
            #expect(settings.shelfOpenOnDrag)
            #expect(settings.shelfMaxItems == 20)
            #expect(settings.shelfAutoRemoveDays == 0)
            #expect(settings.shelfConfirmClear)
            #expect(!settings.shelfRemoveAfterDragOut)
            #expect(settings.calendarInNotch)
            #expect(settings.calendarLeadMinutes == 5)
            #expect(settings.calendarDaysAhead == 7)
            #expect(settings.calendarShowAllDay)
            #expect(settings.calendarHiddenIDs.isEmpty)
            #expect(settings.batteryChargingFlash)
            #expect(settings.batteryLowWarning)
            #expect(settings.batteryLowThreshold == 10)
            #expect(!settings.systemTransferInNotch)  // off: no background sampling
            #expect(settings.systemTransferThreshold == 5)
        }
    }

    @Test func textOverridesFromTheCommandLineAreUnderstood() {
        withIsolatedDefaults { defaults in
            // `-pomodoro.focusMinutes 1` arrives as the text "1", not a number.
            defaults.set("1", forKey: NumericSetting.focusMinutes.key)
            defaults.set("NO", forKey: BoolSetting.autoStartBreaks.key)
            let settings = AppSettings(defaults: defaults)
            #expect(settings.focusMinutes == 1)
            #expect(!settings.autoStartBreaks)
        }
    }

    @Test func changesAreSavedAndReloaded() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.hoverDelay = 0.5
            settings.hapticsEnabled = false
            settings.expandedWidth = 720
            settings.focusMinutes = 50
            settings.autoStartFocus = true
            settings.pomodoroSound = "Hero"

            let reloaded = AppSettings(defaults: defaults)
            #expect(reloaded.hoverDelay == 0.5)
            #expect(!reloaded.hapticsEnabled)
            #expect(reloaded.expandedWidth == 720)
            #expect(reloaded.focusMinutes == 50)
            #expect(reloaded.autoStartFocus)
            #expect(reloaded.pomodoroSound == "Hero")
        }
    }

    @Test func outOfRangeSavedValuesAreClampedOnLoad() {
        withIsolatedDefaults { defaults in
            defaults.set(5000.0, forKey: NumericSetting.expandedWidth.key)
            defaults.set(-3.0, forKey: NumericSetting.hoverDelay.key)
            let settings = AppSettings(defaults: defaults)
            #expect(settings.expandedWidth == 900)
            #expect(settings.hoverDelay == 0)
        }
    }

    @Test func sizesBelowTheMinimumAreRaisedSoLayoutsStillFit() {
        withIsolatedDefaults { defaults in
            defaults.set(300.0, forKey: NumericSetting.expandedWidth.key)
            defaults.set(100.0, forKey: NumericSetting.expandedHeight.key)
            defaults.set(-5.0, forKey: NumericSetting.compactWingWidth.key)
            let settings = AppSettings(defaults: defaults)
            #expect(settings.expandedWidth == 560)
            #expect(settings.expandedHeight == 190)
            #expect(settings.compactWingWidth == 0)  // never narrower than the notch itself
        }
    }

    @Test func resetRestoresAndSavesDefaults() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.closeDelay = 1.2
            settings.expandedHeight = 350
            settings.hapticsEnabled = false
            settings.focusMinutes = 45
            settings.pomodoroSound = "Frog"

            settings.resetToDefaults()
            #expect(settings.closeDelay == 0.15)
            #expect(settings.expandedHeight == 200)
            #expect(settings.hapticsEnabled)
            #expect(settings.focusMinutes == 25)
            #expect(settings.pomodoroSound == "Glass")

            let reloaded = AppSettings(defaults: defaults)
            #expect(reloaded.closeDelay == 0.15)
        }
    }
}
