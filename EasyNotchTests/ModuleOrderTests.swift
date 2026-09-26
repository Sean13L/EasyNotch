import AppKit
import Testing
@testable import EasyNotch

struct ModuleOrderTests {
    @Test func aSavedOrderIsCleanedUp() {
        #expect(NotchModule.ordered(from: []) == [.music, .shelf, .pomodoro])
        #expect(NotchModule.ordered(from: ["pomodoro", "music", "shelf"]) == [.pomodoro, .music, .shelf])
        // Repeats and unknown names are dropped; missing modules are added at the end.
        #expect(NotchModule.ordered(from: ["shelf", "shelf", "weather"]) == [.shelf, .music, .pomodoro])
    }

    @Test func hiddenTabsAreLeftOutButOneAlwaysStays() {
        let order = ["pomodoro", "music", "shelf"]
        #expect(NotchModule.visible(order: order, hidden: ["music"]) == [.pomodoro, .shelf])
        #expect(NotchModule.visible(order: order, hidden: ["music", "shelf", "pomodoro"]) == [.pomodoro])
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
