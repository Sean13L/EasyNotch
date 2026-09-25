import CoreServices
import Foundation

/// Runs AppleScript to talk to music apps, and checks whether macOS allows that.
///
/// It runs on its own serial queue rather than the shared pool Swift uses for async work.
/// That's because some calls here can block for a long time: a player that's slow to answer,
/// or a permission prompt waiting for the user.
actor AppleScriptRunner {
    enum Failure: Error, Equatable {
        case notAuthorized
        case playerNotRunning
        case timedOut
        case failed(code: Int, message: String)
    }

    private let queue = DispatchSerialQueue(label: "com.seanl.easynotch.applescript")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    /// Compiled scripts, reused because compiling is the slow part.
    private var compiled: [String: NSAppleScript] = [:]

    /// Runs `source` and turns the result into a value with `parse`.
    func run<T: Sendable>(
        _ source: String, parse: @Sendable (NSAppleEventDescriptor) -> T?
    ) throws(Failure) -> T? {
        parse(try execute(source))
    }

    /// Runs `source`, ignoring the result (for commands like play/pause).
    func run(_ source: String) throws(Failure) {
        _ = try execute(source)
    }

    /// Asks macOS whether EasyNotch may control the app. With `askIfNeeded`, macOS shows its
    /// permission prompt if the user hasn't decided yet, and this waits for the answer.
    func permission(for bundleID: String, askIfNeeded: Bool) -> AutomationPermission {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, AEEventClass(typeWildCard), AEEventID(typeWildCard), askIfNeeded
        )
        switch Int(status) {
        case Int(noErr): return .granted
        case -1743: return .denied            // errAEEventNotPermitted
        case -1744: return .notDetermined     // errAEEventWouldRequireUserConsent
        case -600: return .playerNotRunning   // procNotFound
        default:
            Log.music.error("Permission check for \(bundleID, privacy: .public) returned \(status)")
            return .unknown
        }
    }

    // MARK: - Private

    private func execute(_ source: String) throws(Failure) -> NSAppleEventDescriptor {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else if let fresh = NSAppleScript(source: source) {
            // Commands with values (seek, volume) differ every time; don't let them pile up.
            if compiled.count > 32 { compiled.removeAll() }
            compiled[source] = fresh
            script = fresh
        } else {
            throw .failed(code: 0, message: "Couldn't create script")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            switch code {
            case -1743: throw .notAuthorized
            case -600, -609: throw .playerNotRunning
            case -1712: throw .timedOut
            default: throw .failed(code: code, message: message)
            }
        }
        return result
    }
}
