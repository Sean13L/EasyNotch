import SwiftUI

/// The accent color for selections and highlights in the notch (Settings → Appearance).
/// Features read it from the environment with `@Environment(\.notchAccent)`.
enum NotchAccent {
    /// Setting value and display name, in menu order.
    static let choices: [(name: String, title: String)] = [
        ("system", "System"), ("blue", "Blue"), ("purple", "Purple"), ("pink", "Pink"),
        ("red", "Red"), ("orange", "Orange"), ("yellow", "Yellow"), ("green", "Green"),
        ("graphite", "Graphite"),
    ]

    static func color(named name: String) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "graphite": .gray
        // "system": ask macOS for the accent color chosen in System Settings → Appearance.
        // (SwiftUI's generic `.accentColor` can come out grey in some windows.)
        default: Color(nsColor: .controlAccentColor)
        }
    }
}

extension EnvironmentValues {
    /// The notch's accent color; see `NotchAccent`.
    @Entry var notchAccent: Color = Color(nsColor: .controlAccentColor)
    /// True when the user picked a specific accent color rather than "System".
    @Entry var hasCustomNotchAccent = false
}
