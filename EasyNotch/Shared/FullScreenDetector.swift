import AppKit

/// Asks macOS whether a screen is currently showing a full-screen app.
///
/// macOS has no public way to ask this, so it uses two undocumented functions from its window
/// system that window managers (yabai, Hammerspoon, …) have relied on for years. They're looked
/// up while the app runs rather than linked directly. If a future macOS removes them,
/// `isFullScreen` just returns false and "Hide while an app is full screen" does nothing.
nonisolated enum FullScreenDetector {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CurrentSpace = @convention(c) (Int32, CFString) -> UInt64
    private typealias SpaceType = @convention(c) (Int32, UInt64) -> Int32

    /// The window system's code for a full-screen Space.
    private static let fullScreenSpaceType: Int32 = 4

    private static let mainConnection: MainConnection? = lookUp("CGSMainConnectionID")
    private static let currentSpace: CurrentSpace? = lookUp("CGSManagedDisplayGetCurrentSpace")
    private static let spaceType: SpaceType? = lookUp("CGSSpaceGetType")

    /// Whether these functions exist on this version of macOS.
    static var isAvailable: Bool {
        mainConnection != nil && currentSpace != nil && spaceType != nil
    }

    static func isFullScreen(displayID: CGDirectDisplayID) -> Bool {
        guard let mainConnection, let currentSpace, let spaceType,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let uuidString = CFUUIDCreateString(nil, uuid)
        else { return false }
        let connection = mainConnection()
        let space = currentSpace(connection, uuidString)
        return spaceType(connection, space) == fullScreenSpaceType
    }

    private static func lookUp<Function>(_ name: String) -> Function? {
        // (void *)-2 is RTLD_DEFAULT: search everything already loaded into the app.
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            Log.notch.notice("\(name, privacy: .public) isn't available; full-screen hiding is off")
            return nil
        }
        return unsafeBitCast(pointer, to: Function.self)
    }
}
