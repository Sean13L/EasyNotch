import Foundation

/// Runs `body` with a throwaway UserDefaults, so tests never touch your real settings.
func withIsolatedDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
    let name = "EasyNotchTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    return try body(defaults)
}

/// Async version, for tests that wait.
func withIsolatedDefaults<T>(_ body: (UserDefaults) async throws -> T) async rethrows -> T {
    let name = "EasyNotchTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    return try await body(defaults)
}
