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

    /// A pretend notch, centered at the top of a screen that has no real one, so the notch
    /// works there too.
    static func virtual(frame: CGRect, notchSize: CGSize) -> ScreenMetrics {
        let width = min(max(notchSize.width, 1), frame.width)
        let side = (frame.width - width) / 2
        return ScreenMetrics(frame: frame, notchHeight: notchSize.height, leftAreaWidth: side, rightAreaWidth: side)
    }
}

/// Where everything goes on one screen, in global AppKit coordinates.
/// Pure math with no AppKit, so it's fully unit-tested.
nonisolated struct NotchGeometry: Equatable, Sendable {
    /// Room around the open shape for its drop shadow and top "ears".
    static let shadowPadding: CGFloat = 24
    /// How far around the notch a file drag opens it. Generous, because you aim less
    /// precisely while dragging.
    static let dragMargin: CGFloat = 40

    let screenFrame: CGRect
    /// The physical notch (the closed state).
    let notchRect: CGRect
    /// A pointer resting here opens the notch.
    let hotZone: CGRect
    /// The notch widened by "wings" on each side, for a live activity (the compact state).
    let compactRect: CGRect
    /// The hover area while the compact state is showing.
    let compactHotZone: CGRect
    /// Dragging files into this area opens the notch.
    let dragHotZone: CGRect
    /// The expanded panel (the open state).
    let openRect: CGRect
    /// The window's frame: room for every state plus the shadow, kept on screen.
    let panelFrame: CGRect

    /// Returns nil for a screen without a notch.
    init?(metrics: ScreenMetrics, openSize: CGSize, compactWingWidth: CGFloat, hotZoneMargin: CGFloat) {
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

        let compact = notchRect.insetBy(dx: -max(0, compactWingWidth), dy: 0)
        compactRect = compact.intersection(screen)
        compactHotZone = compactRect.insetBy(dx: -hotZoneMargin, dy: -hotZoneMargin)
        dragHotZone = compactRect.insetBy(dx: -Self.dragMargin, dy: -Self.dragMargin)

        // Never smaller than the notch, never wider or taller than the screen.
        let width = min(max(openSize.width, notchWidth), screen.width)
        let height = min(max(openSize.height, metrics.notchHeight), screen.height)
        // Centered under the notch, but slid sideways if that would leave the screen.
        let x = min(max(notchRect.midX - width / 2, screen.minX), screen.maxX - width)
        openRect = CGRect(x: x, y: screen.maxY - height, width: width, height: height)

        let padding = Self.shadowPadding
        let content = openRect.union(compactRect)
        panelFrame = CGRect(
            x: content.minX - padding,
            y: content.minY - padding,
            width: content.width + padding * 2,
            height: content.height + padding
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
