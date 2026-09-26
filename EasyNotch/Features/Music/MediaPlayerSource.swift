import AppKit
import Observation

/// One music app (Spotify or Music) as EasyNotch sees it: whether it's open, what it's
/// playing, its cover art, and whether we're allowed to control it.
///
/// Two ways of learning about the player:
/// - **Listening:** the app broadcasts a notification when the track or play state changes.
///   This is instant and needs no permission.
/// - **Asking:** AppleScript gives the full picture (position, volume, artwork) and sends
///   commands. It needs the user's permission. Background refreshes only ask once permission
///   is already granted, so EasyNotch never pops up a prompt out of nowhere.
@Observable
final class MediaPlayerSource {
    let profile: PlayerProfile

    private(set) var isRunning = false
    private(set) var snapshot: PlayerSnapshot?
    private(set) var artwork: NSImage? {
        didSet { artworkColor = artwork.flatMap(ArtworkColor.color(of:)) }
    }
    /// The standout color of the cover art, for the audio bars (see `ArtworkColor`).
    private(set) var artworkColor: NSColor?
    private(set) var permission: AutomationPermission = .unknown
    /// When this player last started playing or changed track; used to pick which player to show.
    private(set) var lastActivity: Date = .distantPast

    var player: MediaPlayer { profile.player }

    @ObservationIgnored private let runner: AppleScriptRunner
    @ObservationIgnored private var notificationObserver: DistributedNotificationObserver?
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    /// The track whose artwork is loaded (or known to be unavailable).
    @ObservationIgnored private var artworkTrackID: String?
    @ObservationIgnored private var artworkLoadingTrackID: String?

    init(profile: PlayerProfile, runner: AppleScriptRunner) {
        self.profile = profile
        self.runner = runner
    }

    /// Starts listening. Called once at launch (never in tests).
    func start() {
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: profile.bundleID).isEmpty

        let parse = profile.parseNotification
        notificationObserver = DistributedNotificationObserver(name: profile.notificationName) { [weak self] note in
            let snapshot = parse(note.userInfo ?? [:], .now)
            self?.didReceive(snapshot)
        }

        let center = NSWorkspace.shared.notificationCenter
        let bundleID = profile.bundleID
        for (name, running) in [
            (NSWorkspace.didLaunchApplicationNotification, true),
            (NSWorkspace.didTerminateApplicationNotification, false),
        ] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == bundleID else { return }
                MainActor.assumeIsolated { self?.setRunning(running) }
            })
        }

        Task { await refresh() }
    }

    // MARK: - Asking the player

    /// Reads the full state with AppleScript. Only asks macOS for permission when
    /// `askPermission` is true, which is only ever the result of a user action.
    func refresh(askPermission: Bool = false) async {
        guard isRunning else { return }
        let checked = await runner.permission(for: profile.bundleID, askIfNeeded: askPermission)
        if checked != permission {
            Log.music.debug("\(self.player.displayName, privacy: .public) permission: \(String(describing: checked), privacy: .public)")
            permission = checked
        }
        guard permission == .granted else { return }

        let now = Date.now
        let parse = profile.parseState
        do {
            let fresh = try await runner.run(profile.stateScript) { parse($0, now) }
            if fresh == nil {
                Log.music.debug("\(self.player.displayName, privacy: .public) state: stopped or unreadable")
            }
            apply(fresh)
        } catch {
            handle(error)
        }
    }

    /// Shows macOS's "allow EasyNotch to control…" prompt (if it hasn't been answered yet).
    func requestPermission() async {
        await refresh(askPermission: true)
    }

    func perform(_ command: PlayerCommand) async {
        guard isRunning else {
            if command == .playPause { openApp() }
            return
        }
        // Flip play/pause right away so the button feels instant; the refresh below corrects it.
        if command == .playPause, var optimistic = snapshot {
            optimistic.position = optimistic.elapsed(at: .now)
            optimistic.positionDate = .now
            optimistic.isPlaying.toggle()
            snapshot = optimistic
        }
        do {
            // If permission hasn't been decided, this is where macOS asks, because the user
            // just pressed a button.
            try await runner.run(profile.commandScript(command))
        } catch {
            handle(error)
        }
        await refresh()
    }

    func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleID) != nil
    }

    var appIcon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    /// Opens System Settings → Privacy & Security → Automation, where the user can turn
    /// control back on after saying no.
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func didReceive(_ notificationSnapshot: PlayerSnapshot?) {
        Log.music.debug("\(self.player.displayName, privacy: .public) broadcast: \(notificationSnapshot.map { $0.isPlaying ? "playing" : "paused" } ?? "stopped", privacy: .public)")
        isRunning = true
        apply(notificationSnapshot)
        // Fill in the details the notification doesn't carry. This never prompts; without
        // permission it just returns.
        Task { await refresh() }
    }

    private func setRunning(_ running: Bool) {
        isRunning = running
        Log.music.notice("\(self.player.displayName, privacy: .public) \(running ? "opened" : "quit", privacy: .public)")
        if running {
            Task { await refresh() }
        } else {
            apply(nil)
            permission = .playerNotRunning
        }
    }

    private func apply(_ fresh: PlayerSnapshot?) {
        let previous = snapshot
        let merged = fresh?.filling(from: previous)
        snapshot = merged

        let startedPlaying = merged?.isPlaying == true && previous?.isPlaying != true
        let changedTrack = merged != nil && merged?.trackID != previous?.trackID
        if startedPlaying || changedTrack {
            lastActivity = .now
        }
        if merged?.trackID != artworkTrackID {
            Task { await loadArtwork() }
        }
    }

    private func loadArtwork() async {
        guard let snapshot else {
            artwork = nil
            artworkTrackID = nil
            return
        }
        let trackID = snapshot.trackID
        guard trackID != artworkTrackID, trackID != artworkLoadingTrackID else { return }
        artworkLoadingTrackID = trackID
        defer { artworkLoadingTrackID = nil }

        var image: NSImage?
        // Whether "no image" is the final answer, or it might work once we know more.
        let isFinal: Bool
        switch profile.artwork {
        case .url:
            isFinal = snapshot.artworkURL != nil
            if let url = snapshot.artworkURL,
               let download = try? await URLSession.shared.data(from: url) {
                image = NSImage(data: download.0)
            }
        case let .script(source):
            isFinal = permission == .granted
            if isFinal {
                let data = try? await runner.run(source) { $0.data.isEmpty ? nil : $0.data }
                image = data.flatMap(NSImage.init(data:))
            }
        }

        // The track may have changed while we were loading; only keep a matching image.
        guard self.snapshot?.trackID == trackID else { return }
        if image != nil || isFinal {
            artworkTrackID = trackID
            artwork = image
            Log.music.debug("\(self.player.displayName, privacy: .public) cover: \(image == nil ? "none" : "loaded", privacy: .public)")
        } else if permission == .granted {
            // A track change arrives first as a notification without the cover's link, and
            // the refresh that follows brings it a moment later. Keep the previous cover up
            // until then, so the wings don't flash the placeholder (and the bars their
            // fallback color) between tracks.
            Log.music.debug("\(self.player.displayName, privacy: .public) cover: keeping the previous one until details arrive")
        } else {
            // Without permission, no more details are coming.
            artwork = nil
        }
    }

    private func handle(_ error: Error) {
        switch error as? AppleScriptRunner.Failure {
        case .notAuthorized:
            permission = .denied
        case .playerNotRunning:
            Log.music.notice("\(self.player.displayName, privacy: .public) didn't answer; treating it as quit")
            isRunning = false
            apply(nil)
        default:
            Log.music.error("\(self.player.displayName, privacy: .public) script failed: \(String(describing: error), privacy: .public)")
        }
    }
}
