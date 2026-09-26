import Foundation
import Testing
@testable import EasyNotch

/// Export, import, and reset.
struct SettingsTransferTests {
    @Test func exportedSettingsImportIntoAFreshMac() throws {
        try withIsolatedDefaults { original in
            let settings = AppSettings(defaults: original)
            settings.hoverDelay = 0.4
            settings.openOnClick = true
            settings.animationStyle = "bouncy"
            settings.moduleOrder = ["pomodoro", "shelf", "music"]
            settings.hiddenModules = ["shelf"]
            settings.shelfAutoRemoveDays = 1

            // Through real JSON, exactly as the Export button writes it.
            let data = try JSONSerialization.data(withJSONObject: settings.exportedValues())
            let values = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

            withIsolatedDefaults { fresh in
                let imported = AppSettings(defaults: fresh)
                let count = imported.importValues(values)
                #expect(count == values.count)
                #expect(imported.hoverDelay == 0.4)
                #expect(imported.openOnClick)
                #expect(imported.animationStyle == "bouncy")
                #expect(imported.moduleOrder == ["pomodoro", "shelf", "music"])
                #expect(imported.hiddenModules == ["shelf"])
                #expect(imported.shelfAutoRemoveDays == 1)  // the number 1 isn't mistaken for "true"
            }
        }
    }

    @Test func badOrUnknownValuesAreIgnoredOrFixed() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let count = settings.importValues([
                "notch.expandedWidth": 5000,          // too big → clamped
                "notch.hoverDelay": "fast",           // wrong type → ignored
                "notch.animationStyle": "wobbly",     // not a choice → default
                "notch.openOnClick": 1,               // not a true/false → ignored
                "something.else": true,               // unknown → ignored
            ])
            #expect(count == 2)
            #expect(settings.expandedWidth == 900)
            #expect(settings.hoverDelay == 0.15)
            #expect(settings.animationStyle == "snappy")
            #expect(!settings.openOnClick)
        }
    }

    @Test func resetCoversTheNewOptions() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.displayMode = "all"
            settings.moduleOrder = ["shelf", "music", "pomodoro"]
            settings.hiddenModules = ["music"]
            settings.shortcutKeyCode = 45
            settings.accentColor = "pink"

            settings.resetToDefaults()
            #expect(settings.displayMode == "builtIn")
            #expect(settings.moduleOrder == ["music", "shelf", "pomodoro", "calendar", "battery", "system"])
            #expect(settings.hiddenModules.isEmpty)
            #expect(settings.shortcutKeyCode == -1)
            #expect(settings.accentColor == "system")

            let reloaded = AppSettings(defaults: defaults)
            #expect(reloaded.displayMode == "builtIn")
        }
    }

    @Test func everyRegisteredSettingIsExported() {
        withIsolatedDefaults { defaults in
            let exported = AppSettings(defaults: defaults).exportedValues()
            let registered = NumericSetting.all.count + BoolSetting.all.count
                + StringSetting.all.count + StringListSetting.all.count
            #expect(exported.count == registered)
        }
    }
}
