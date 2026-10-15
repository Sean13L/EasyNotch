import Testing
@testable import EasyNotch

/// Checks when the Spotify Spatial Audio relay may run.
struct SpatialAudioPolicyTests {
    @Test func offWhenTheSettingIsOff() {
        #expect(SpatialAudioPolicy.decide(enabled: false, spotifyPlaying: true, outputIsAirPods: true,
                                          permissionConfirmed: true, userRequested: true) == .off)
    }

    @Test func waitsForSpotifyToPlay() {
        #expect(SpatialAudioPolicy.decide(enabled: true, spotifyPlaying: false, outputIsAirPods: true,
                                          permissionConfirmed: true, userRequested: false) == .waitForSpotify)
    }

    @Test func needsAirPodsAsTheOutput() {
        #expect(SpatialAudioPolicy.decide(enabled: true, spotifyPlaying: true, outputIsAirPods: false,
                                          permissionConfirmed: true, userRequested: false) == .wrongOutput)
    }

    @Test func aBackgroundStartNeedsAConfirmedPermission() {
        #expect(SpatialAudioPolicy.decide(enabled: true, spotifyPlaying: true, outputIsAirPods: true,
                                          permissionConfirmed: false, userRequested: false) == .needsPermission)
    }

    @Test func aUserActionMayAskForThePermission() {
        #expect(SpatialAudioPolicy.decide(enabled: true, spotifyPlaying: true, outputIsAirPods: true,
                                          permissionConfirmed: false, userRequested: true) == .relay)
    }

    @Test func runsWhenEverythingIsReadyAndPermissionIsConfirmed() {
        #expect(SpatialAudioPolicy.decide(enabled: true, spotifyPlaying: true, outputIsAirPods: true,
                                          permissionConfirmed: true, userRequested: false) == .relay)
    }

    @Test func theSettingIsOffForNewInstalls() {
        withIsolatedDefaults { defaults in
            #expect(!AppSettings(defaults: defaults).spatialAudioSpotify)
        }
    }
}
