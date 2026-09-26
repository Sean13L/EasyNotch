import AppKit
import Carbon.HIToolbox

/// Registers one system-wide keyboard shortcut with macOS.
///
/// It uses macOS's long-standing hot-key API (from "Carbon", the older Mac framework), which
/// works in every app *without* the Accessibility permission that watching keystrokes
/// would need.
final class HotKeyCenter {
    var onPress: (() -> Void)?

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// Replaces the current shortcut. A negative key code means no shortcut.
    func register(keyCode: Int, carbonModifiers: Int) {
        unregister()
        guard keyCode >= 0, carbonModifiers != 0 else { return }
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x454E_4F54), id: 1)  // "ENOT"
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(carbonModifiers), id, GetApplicationEventTarget(), 0, &hotKey
        )
        if status == noErr {
            Log.app.notice("Keyboard shortcut registered")
        } else {
            // Most often another app already uses the same shortcut.
            Log.app.error("Couldn't register the keyboard shortcut (\(status))")
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // The callback is plain C, so it can't capture `self`; pass a pointer to it instead.
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { center.onPress?() }
            return noErr
        }, 1, &pressed, context, &handler)
    }

    // MARK: - Converting and showing shortcuts

    /// Converts AppKit's modifier flags into the format the hot-key API expects.
    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return result
    }

    /// How a shortcut is written in menus, e.g. "⌃⌥⇧⌘N".
    nonisolated static func displayString(modifiers flags: NSEvent.ModifierFlags, key: String) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + key
    }

    /// A readable name for a key, e.g. "N", "Space", "→", "F5".
    nonisolated static func keyName(keyCode: Int, characters: String?) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[keyCode] { return name }
        return (characters ?? "?").uppercased()
    }
}
