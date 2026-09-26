import Foundation

/// One calendar event, with just what the notch needs. Built from EventKit by `CalendarService`.
nonisolated struct Meeting: Equatable, Identifiable, Sendable {
    /// A calendar color as plain numbers, so this type doesn't depend on AppKit.
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
    }

    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: RGB
    /// A Zoom/Meet/Teams/Webex/FaceTime link found in the event, if any.
    let joinURL: URL?
}
