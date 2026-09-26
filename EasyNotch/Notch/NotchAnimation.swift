import AppKit
import SwiftUI

/// How the notch moves when it opens and closes (Settings → Appearance).
enum NotchAnimation: String, CaseIterable, Identifiable {
    case snappy
    case smooth
    case bouncy
    case minimal

    var id: Self { self }

    /// The chosen style, or `minimal` whenever macOS's "Reduce motion" accessibility setting is on.
    static func current(settingName: String) -> NotchAnimation {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return .minimal }
        return NotchAnimation(rawValue: settingName) ?? .snappy
    }

    var title: String {
        switch self {
        case .snappy: "Snappy"
        case .smooth: "Smooth"
        case .bouncy: "Bouncy"
        case .minimal: "Minimal"
        }
    }

    var summary: String {
        switch self {
        case .snappy: "Quick, with a hint of spring."
        case .smooth: "Glides open with no bounce."
        case .bouncy: "Playful spring when it opens."
        case .minimal: "A quick, plain change. Used automatically when “Reduce motion” is on."
        }
    }

    var opening: Animation {
        switch self {
        case .snappy: .spring(response: 0.38, dampingFraction: 0.8)
        case .smooth: .spring(response: 0.5, dampingFraction: 1)
        case .bouncy: .spring(response: 0.45, dampingFraction: 0.62)
        case .minimal: .easeOut(duration: 0.12)
        }
    }

    /// Closing is quicker and calmer than opening, so the notch gets out of the way.
    var closing: Animation {
        switch self {
        case .snappy: .spring(response: 0.28, dampingFraction: 0.9)
        case .smooth: .spring(response: 0.36, dampingFraction: 1)
        case .bouncy: .spring(response: 0.32, dampingFraction: 0.75)
        case .minimal: .easeIn(duration: 0.1)
        }
    }
}
