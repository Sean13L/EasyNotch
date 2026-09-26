import AppKit

extension NSScreen {
    /// A stable ID for this display, used to keep one notch window per screen.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// True for a laptop's own screen (as opposed to an external monitor).
    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
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

    /// Measurements for a pretend notch of the given width, as tall as this screen's menu bar.
    func virtualNotchMetrics(width: CGFloat) -> ScreenMetrics {
        let menuBarHeight = frame.maxY - visibleFrame.maxY
        // With an auto-hiding menu bar there's no visible height to copy; use the standard one.
        let height = menuBarHeight > 0 ? menuBarHeight : NSStatusBar.system.thickness
        return .virtual(frame: frame, notchSize: CGSize(width: width, height: height))
    }
}
