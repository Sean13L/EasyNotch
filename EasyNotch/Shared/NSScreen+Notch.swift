import AppKit

extension NSScreen {
    /// A stable ID for this display, used to keep one notch window per screen.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// This screen's notch measurements, or nil if it has no notch.
    var notchMetrics: ScreenMetrics? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea
        else { return nil }
        return ScreenMetrics(
            frame: frame,
            notchHeight: safeAreaInsets.top,
            leftAreaWidth: left.width,
            rightAreaWidth: right.width
        )
    }
}
