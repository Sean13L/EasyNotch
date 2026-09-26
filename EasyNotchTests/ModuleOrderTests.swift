import AppKit
import Testing
@testable import EasyNotch

struct ModuleOrderTests {
    @Test func aSavedOrderIsCleanedUp() {
        #expect(NotchModule.ordered(from: []) == [.music, .shelf, .pomodoro, .calendar, .battery, .system])
        // A 1.0 order (three tabs) gets the new tabs added at the end.
        #expect(NotchModule.ordered(from: ["pomodoro", "music", "shelf"]) == [.pomodoro, .music, .shelf, .calendar, .battery, .system])
        // Repeats and unknown names are dropped; missing modules are added at the end.
        #expect(NotchModule.ordered(from: ["shelf", "shelf", "weather"]) == [.shelf, .music, .pomodoro, .calendar, .battery, .system])
    }

    @Test func hiddenTabsAreLeftOutButOneAlwaysStays() {
        let order = ["pomodoro", "music", "shelf", "calendar", "battery", "system"]
        #expect(NotchModule.visible(order: order, hidden: ["music", "calendar"]) == [.pomodoro, .shelf, .battery, .system])
        #expect(NotchModule.visible(order: order, hidden: order) == [.pomodoro])
    }

    @Test func draggingATabOntoAnotherTakesItsPlace() {
        let order: [NotchModule] = [.music, .shelf, .pomodoro]
        #expect(NotchModule.reordered(order, moving: .pomodoro, onto: .music) == [.pomodoro, .music, .shelf])
        #expect(NotchModule.reordered(order, moving: .music, onto: .pomodoro) == [.shelf, .pomodoro, .music])
        #expect(NotchModule.reordered(order, moving: .shelf, onto: .shelf) == order)
    }

    // MARK: - Keyboard shortcut text

    @Test func shortcutsAreWrittenLikeInMenus() {
        let all: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        #expect(HotKeyCenter.displayString(modifiers: all, key: "N") == "⌃⌥⇧⌘N")
        #expect(HotKeyCenter.displayString(modifiers: [.command], key: "Space") == "⌘Space")
        #expect(HotKeyCenter.keyName(keyCode: 49, characters: " ") == "Space")
        #expect(HotKeyCenter.keyName(keyCode: 45, characters: "n") == "N")
    }

    @Test func modifiersConvertToTheHotKeyFormat() {
        // cmdKey = 256, shiftKey = 512, optionKey = 2048, controlKey = 4096
        #expect(HotKeyCenter.carbonModifiers(from: [.command]) == 256)
        #expect(HotKeyCenter.carbonModifiers(from: [.command, .option]) == 256 + 2048)
        #expect(HotKeyCenter.carbonModifiers(from: [.control, .shift]) == 4096 + 512)
    }
}
