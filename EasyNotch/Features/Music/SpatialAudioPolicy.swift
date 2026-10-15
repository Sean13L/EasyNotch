import Foundation

/// Decides whether the Spotify Spatial Audio relay should run right now.
/// It only looks at plain values, so it can be tested without Core Audio.
nonisolated enum SpatialAudioPolicy {
    enum Decision: Equatable, Sendable {
        /// Setting is off: nothing runs.
        case off
        /// Setting is on, but Spotify isn't playing. The relay starts when it does.
        case waitForSpotify
        /// Spotify is playing, but the output isn't AirPods, which is the only thing Spatial Audio works with.
        case wrongOutput
        /// Permission to capture system audio hasn't been confirmed. Only a user action may ask for it.
        case needsPermission
        case relay
    }

    /// - Parameters:
    ///   - permissionConfirmed: the user has already allowed capture in a successful start.
    ///   - userRequested: the user just turned the setting on or pressed "Allow". Only then may macOS show its prompt.
    static func decide(
        enabled: Bool,
        spotifyPlaying: Bool,
        outputIsAirPods: Bool,
        permissionConfirmed: Bool,
        userRequested: Bool
    ) -> Decision {
        guard enabled else { return .off }
        guard spotifyPlaying else { return .waitForSpotify }
        guard outputIsAirPods else { return .wrongOutput }
        guard permissionConfirmed || userRequested else { return .needsPermission }
        return .relay
    }
}
