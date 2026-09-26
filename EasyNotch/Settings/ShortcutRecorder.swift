import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A button that records a keyboard shortcut: click it, then press the keys.
/// Esc cancels, Delete clears, and the shortcut must include ⌘, ⌥, or ⌃ so a plain letter can't
/// take over typing everywhere.
struct ShortcutRecorder: View {
    @Bindable var settings: AppSettings

    @State private var recording = ShortcutRecording()

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if settings.isRecordingShortcut {
                    recording.stop(settings)
                } else {
                    recording.start(settings)
                }
            } label: {
                Text(label)
                    .frame(minWidth: 130)
            }
            if !settings.shortcutDisplay.isEmpty, !settings.isRecordingShortcut {
                Button("Clear") { ShortcutRecording.clear(settings) }
            }
        }
        .onDisappear { recording.stop(settings) }
    }

    private var label: String {
        if settings.isRecordingShortcut { return "Type a shortcut…" }
        return settings.shortcutDisplay.isEmpty ? "Record Shortcut" : settings.shortcutDisplay
    }
}

/// Catches the next key combination typed while the Settings window is in front.
private final class ShortcutRecording {
    private var monitor: Any?

    func start(_ settings: AppSettings) {
        stop(settings)
        // Pauses the current shortcut (see AppServices) so its keys reach us.
        settings.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event, settings)
            return nil  // keep the keys from doing anything else
        }
    }

    func stop(_ settings: AppSettings) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        settings.isRecordingShortcut = false
    }

    static func clear(_ settings: AppSettings) {
        settings.shortcutKeyCode = NumericSetting.shortcutKeyCode.defaultValue
        settings.shortcutModifiers = NumericSetting.shortcutModifiers.defaultValue
        settings.shortcutDisplay = StringSetting.shortcutDisplay.defaultValue
    }

    private func handle(_ event: NSEvent, _ settings: AppSettings) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stop(settings)
            return
        case kVK_Delete, kVK_ForwardDelete:
            Self.clear(settings)
            stop(settings)
            return
        default:
            break
        }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.intersection([.command, .option, .control]).isEmpty else {
            NSSound.beep()  // needs ⌘, ⌥, or ⌃
            return
        }
        let key = HotKeyCenter.keyName(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
        settings.shortcutKeyCode = Double(event.keyCode)
        settings.shortcutModifiers = Double(HotKeyCenter.carbonModifiers(from: modifiers))
        settings.shortcutDisplay = HotKeyCenter.displayString(modifiers: modifiers, key: key)
        stop(settings)
    }
}
