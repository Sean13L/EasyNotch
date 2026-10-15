import AppKit
import AudioToolbox
import Observation

/// Keeps the Spotify Spatial Audio relay running whenever Spotify plays, without a button press.
///
/// It starts and stops the relay when Spotify starts or pauses, or when the output changes.
/// It never asks macOS for the audio permission on its own. Only a user action can do that,
/// and once the permission has worked, background starts may use it without a prompt.
@Observable
final class SpatialAudioController {
    /// What the Music pane shows.
    enum Status: Equatable {
        case off
        case waitingForSpotify
        case wrongOutput
        case needsPermission
        case relaying
        case failed
        case unsupported
    }

    private(set) var status: Status = .off

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let spotify: MediaPlayerSource
    /// The running relay. Stored as `Any` because the relay needs macOS 14.2 and a stored
    /// property can't carry that availability; `relay` below gives the typed view.
    @ObservationIgnored private var activeRelay: Any?
    @available(macOS 14.2, *)
    private var relay: SpatialAudioRelay? {
        get { activeRelay as? SpatialAudioRelay }
        set { activeRelay = newValue }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var outputListener: AudioObjectPropertyListenerBlock?

    /// Set after a relay start works, so later starts can run without asking.
    private static let permissionKey = "spatialAudio.permissionConfirmed"

    init(settings: AppSettings, spotify: MediaPlayerSource, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.spotify = spotify
        self.defaults = defaults
    }

    /// Starts watching Spotify and the output device. Called once at launch (never in tests).
    func activate() {
        watchSpotify()
        watchOutputDevice()
        evaluate(userRequested: false)
    }

    /// The user turned the setting on or off, or pressed "Try again" in the Music pane.
    /// Only this path may show macOS's permission prompt.
    func userRequested() {
        evaluate(userRequested: true)
    }

    /// Short text for the Music pane, describing what the relay is doing.
    var statusText: String {
        switch status {
        case .off: "Off"
        case .waitingForSpotify: "Waiting for Spotify to play"
        case .wrongOutput: "Choose AirPods as the output"
        case .needsPermission: "Needs permission"
        case .relaying: "On"
        case .failed: "Couldn't start"
        case .unsupported: "Needs macOS 14.2 or later"
        }
    }

    // MARK: - Deciding

    private func evaluate(userRequested: Bool) {
        guard #available(macOS 14.2, *) else {
            status = .unsupported
            return
        }
        let decision = SpatialAudioPolicy.decide(
            enabled: settings.spatialAudioSpotify,
            spotifyPlaying: spotify.snapshot?.isPlaying == true,
            outputIsAirPods: Self.outputIsAirPods(),
            permissionConfirmed: defaults.bool(forKey: Self.permissionKey),
            userRequested: userRequested
        )
        switch decision {
        case .relay:
            startRelay(userRequested: userRequested)
        case .off:
            stopRelay()
            status = .off
        case .waitForSpotify:
            stopRelay()
            status = .waitingForSpotify
        case .wrongOutput:
            stopRelay()
            status = .wrongOutput
        case .needsPermission:
            stopRelay()
            status = .needsPermission
        }
    }

    @available(macOS 14.2, *)
    private func startRelay(userRequested: Bool) {
        guard relay == nil else { return }
        guard let spotifyApp = NSRunningApplication.runningApplications(withBundleIdentifier: Spotify.bundleID).first,
              let output = SpatialAudioRelay.defaultOutputDevice()
        else {
            status = .failed
            return
        }

        let newRelay = SpatialAudioRelay()
        do {
            try newRelay.start(spotifyPID: spotifyApp.processIdentifier, outputUID: output.uid)
            relay = newRelay
            defaults.set(true, forKey: Self.permissionKey)
            status = .relaying
            Log.music.notice("Spatial Audio relay started for Spotify")
        } catch {
            // Most likely the user refused the "Screen & System Audio Recording" permission. Forget
            // the confirmation, so background code doesn't try again without asking.
            defaults.set(false, forKey: Self.permissionKey)
            status = .failed
            Log.music.error("Spatial Audio relay failed (user requested \(userRequested, privacy: .public)): \(String(describing: error), privacy: .public)")
        }
    }

    @available(macOS 14.2, *)
    private func stopRelay() {
        guard let relay else { return }
        relay.stop()
        self.relay = nil
        Log.music.notice("Spatial Audio relay stopped")
    }

    /// True when the output is AirPods, the only devices Spatial Audio works with.
    @available(macOS 14.2, *)
    private static func outputIsAirPods() -> Bool {
        SpatialAudioRelay.defaultOutputDevice()?.name.localizedCaseInsensitiveContains("AirPods") == true
    }

    // MARK: - Watching

    /// Re-evaluates whenever Spotify starts or pauses (or quits).
    private func watchSpotify() {
        withObservationTracking {
            _ = spotify.snapshot?.isPlaying
        } onChange: { [weak self] in
            // onChange fires just before the change is stored; look on the next main-loop turn.
            Task { @MainActor [weak self] in
                self?.evaluate(userRequested: false)
                self?.watchSpotify()
            }
        }
    }

    /// Re-evaluates when the output device changes, e.g. when AirPods connect or disconnect.
    private func watchOutputDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.evaluate(userRequested: false)
            }
        }
        outputListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }
}
