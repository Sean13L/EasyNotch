import CoreGraphics

/// The raw numbers `NotchGeometry` needs from a screen. A plain struct (not `NSScreen`)
/// so tests can describe any screen without real hardware.
nonisolated struct ScreenMetrics: Equatable, Sendable {
    /// The whole screen in global AppKit coordinates (origin bottom-left, y grows upward).
    var frame: CGRect
    /// Height of the notch; 0 when the screen has none.
    var notchHeight: CGFloat
    /// Width of the menu-bar area left of the notch.
    var leftAreaWidth: CGFloat
    /// Width of the menu-bar area right of the notch.
    var rightAreaWidth: CGFloat
}

/// Where everything goes on one screen, in global AppKit coordinates.
/// Pure math with no AppKit, so it's fully unit-tested.
nonisolated struct NotchGeometry: Equatable, Sendable {
    /// Room around the open shape for its drop shadow and top "ears".
    static let shadowPadding: CGFloat = 24

    let screenFrame: CGRect
    /// The physical notch (the closed state).
    let notchRect: CGRect
    /// A pointer resting here opens the notch.
    let hotZone: CGRect
    /// The expanded panel (the open state).
    let openRect: CGRect
    /// The window's frame: `openRect` plus shadow room, kept on screen.
    let panelFrame: CGRect

    /// Returns nil for a screen without a notch.
    init?(metrics: ScreenMetrics, openSize: CGSize, hotZoneMargin: CGFloat) {
        let screen = metrics.frame
        let notchWidth = screen.width - metrics.leftAreaWidth - metrics.rightAreaWidth
        guard metrics.notchHeight > 0, notchWidth > 0 else { return nil }

        screenFrame = screen
        notchRect = CGRect(
            x: screen.minX + metrics.leftAreaWidth,
            y: screen.maxY - metrics.notchHeight,
            width: notchWidth,
            height: metrics.notchHeight
        )
        // Also grows upward past the screen edge, so the very top row of pixels counts.
        hotZone = notchRect.insetBy(dx: -hotZoneMargin, dy: -hotZoneMargin)

        // Never smaller than the notch, never wider or taller than the screen.
        let width = min(max(openSize.width, notchWidth), screen.width)
        let height = min(max(openSize.height, metrics.notchHeight), screen.height)
        // Centered under the notch, but slid sideways if that would leave the screen.
        let x = min(max(notchRect.midX - width / 2, screen.minX), screen.maxX - width)
        openRect = CGRect(x: x, y: screen.maxY - height, width: width, height: height)

        let padding = Self.shadowPadding
        panelFrame = CGRect(
            x: openRect.minX - padding,
            y: openRect.minY - padding,
            width: openRect.width + padding * 2,
            height: openRect.height + padding
        ).intersection(screen)
    }

    /// Converts a global rect into the panel's SwiftUI space
    /// (origin at the panel's top-left, y grows downward).
    func localRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - panelFrame.minX,
            y: panelFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
