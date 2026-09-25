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
        }
    }

    @Test func changesAreSavedAndReloaded() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.hoverDelay = 0.5
            settings.hapticsEnabled = false
            settings.expandedWidth = 720

            let reloaded = AppSettings(defaults: defaults)
            #expect(reloaded.hoverDelay == 0.5)
            #expect(!reloaded.hapticsEnabled)
            #expect(reloaded.expandedWidth == 720)
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

    @Test func resetRestoresAndSavesDefaults() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.closeDelay = 1.2
            settings.expandedHeight = 350
            settings.hapticsEnabled = false

            settings.resetToDefaults()
            #expect(settings.closeDelay == 0.15)
            #expect(settings.expandedHeight == 200)
            #expect(settings.hapticsEnabled)

            let reloaded = AppSettings(defaults: defaults)
            #expect(reloaded.closeDelay == 0.15)
        }
    }
}
