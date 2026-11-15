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
    /// The Claude answer card's width, and its height below the notch.
    static let cardSize = CGSize(width: 380, height: 110)
    /// The Claude pill's width, and the gap between it and the notch.
    static let pillWidth: CGFloat = 96
    static let pillGap: CGFloat = 6

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
    /// The hover margin, kept for the Claude pill's hover area.
    let hotZoneMargin: CGFloat
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
        self.hotZoneMargin = hotZoneMargin
        dragHotZone = compactRect.insetBy(dx: -Self.dragMargin, dy: -Self.dragMargin)

        // Never smaller than the notch, never wider or taller than the screen.
        let width = min(max(openSize.width, notchWidth), screen.width)
        let height = min(max(openSize.height, metrics.notchHeight), screen.height)
        // Centered under the notch, but slid sideways if that would leave the screen.
        let x = min(max(notchRect.midX - width / 2, screen.minX), screen.maxX - width)
        openRect = CGRect(x: x, y: screen.maxY - height, width: width, height: height)

        let padding = Self.shadowPadding
        // The pill and card sit farthest left beside the wings; make room for them there.
        let pill = Self.pill(beside: compactRect, notch: notchRect, screen: screen)
        let content = openRect.union(compactRect).union(pill)
            .union(Self.card(under: pill, notch: notchRect, open: openRect, screen: screen))
        panelFrame = CGRect(
            x: content.minX - padding,
            y: content.minY - padding,
            width: content.width + padding * 2,
            height: content.height + padding
        ).intersection(screen)
    }

    /// The Claude pill just left of `shape` (the notch, or the notch with its wings).
    func claudePill(beside shape: CGRect) -> CGRect {
        Self.pill(beside: shape, notch: notchRect, screen: screenFrame)
    }

    /// The Claude answer card, dropping down from the top of the screen under `pill`.
    func claudeCard(under pill: CGRect) -> CGRect {
        Self.card(under: pill, notch: notchRect, open: openRect, screen: screenFrame)
    }

    private static func pill(beside shape: CGRect, notch: CGRect, screen: CGRect) -> CGRect {
        CGRect(x: max(shape.minX - pillGap - pillWidth, screen.minX), y: notch.minY, width: pillWidth, height: notch.height)
    }

    /// Starts at the pill's left edge and is never bigger than the open panel, so it fits.
    private static func card(under pill: CGRect, notch: CGRect, open: CGRect, screen: CGRect) -> CGRect {
        let width = min(cardSize.width, open.width)
        let height = min(notch.height + cardSize.height, open.height)
        let x = min(max(pill.minX, screen.minX), screen.maxX - width)
        return CGRect(x: x, y: screen.maxY - height, width: width, height: height)
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
