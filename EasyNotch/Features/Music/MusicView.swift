import SwiftUI

/// The Music tab in the open notch.
struct MusicView: View {
    @Environment(NowPlayingService.self) private var nowPlaying

    var body: some View {
        Group {
            if let source = nowPlaying.active {
                NowPlayingPanel(source: source)
            } else {
                NothingPlayingView(sources: nowPlaying.sources)
            }
        }
        // Get an up-to-date position whenever the tab appears.
        .task { await nowPlaying.refreshActive() }
    }
}

private struct NowPlayingPanel: View {
    let source: MediaPlayerSource

    @Environment(NowPlayingService.self) private var nowPlaying

    var body: some View {
        HStack(spacing: 20) {
            MusicArtwork(image: source.artwork)
                .frame(width: 118, height: 118)

            VStack(spacing: 8) {
                header
                if let snapshot = source.snapshot {
                    Scrubber(source: source, snapshot: snapshot)
                    TransportControls(source: source, snapshot: snapshot)
                }
                PermissionHint(source: source)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.snapshot?.title ?? "\(source.player.displayName) is open")
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let volume = source.snapshot?.volume {
                VolumeSlider(source: source, volume: volume)
            }
            ForEach(nowPlaying.alternatives, id: \.player) { other in
                AppIconButton(source: other, help: "Switch to \(other.player.displayName)") {
                    nowPlaying.switchTo(other)
                }
                .opacity(0.5)
            }
            AppIconButton(source: source, help: "Open \(source.player.displayName)") {
                source.openApp()
            }
        }
    }

    private var subtitle: String {
        guard let snapshot = source.snapshot else {
            // Without permission we only learn about tracks when they start playing.
            return source.permission == .granted ? "Nothing playing" : "Play something to see it here"
        }
        return [snapshot.artist, snapshot.album].filter { !$0.isEmpty }.joined(separator: " — ")
    }
}

/// Elapsed time, a draggable progress bar, and time remaining. Both time labels have the same
/// width, so the bar's middle lines up with the centered controls below it.
private struct Scrubber: View {
    let source: MediaPlayerSource
    let snapshot: PlayerSnapshot

    @State private var dragPosition: Double?
    private let labelWidth: CGFloat = 44

    var body: some View {
        if let duration = snapshot.duration, duration > 0, snapshot.position != nil {
            SecondsTimeline(isRunning: snapshot.isPlaying && dragPosition == nil) { now in
                let elapsed = dragPosition ?? snapshot.elapsed(at: now) ?? 0
                HStack(spacing: 8) {
                    Text(PlayerSnapshot.clock(elapsed))
                        .frame(width: labelWidth, alignment: .trailing)
                    Slider(
                        value: Binding(get: { elapsed }, set: { dragPosition = $0 }),
                        in: 0...duration,
                        onEditingChanged: { isDragging in
                            guard !isDragging, let target = dragPosition else { return }
                            Task {
                                await source.perform(.seek(to: target))
                                dragPosition = nil
                            }
                        }
                    )
                    .controlSize(.mini)
                    .tint(.white)
                    Text("-" + PlayerSnapshot.clock(duration - elapsed))
                        .frame(width: labelWidth, alignment: .leading)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Shuffle · previous · play/pause · next · repeat, centered under the progress bar.
private struct TransportControls: View {
    let source: MediaPlayerSource
    let snapshot: PlayerSnapshot

    var body: some View {
        HStack(spacing: 18) {
            // Shuffle and repeat keep their slots even when unavailable (before permission is
            // granted), so the play button always sits exactly in the middle.
            ToggleSlot(isAvailable: snapshot.shuffle != nil) {
                ControlButton(
                    systemImage: "shuffle", help: "Shuffle",
                    isOn: snapshot.shuffle, onColor: source.player.accentColor
                ) { send(.toggleShuffle) }
            }
            ControlButton(systemImage: "backward.fill", help: "Previous") { send(.previous) }
            Button { send(.playPause) } label: {
                Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(.white, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(snapshot.isPlaying ? "Pause" : "Play")
            ControlButton(systemImage: "forward.fill", help: "Next") { send(.next) }
            ToggleSlot(isAvailable: snapshot.repeatMode != nil) {
                ControlButton(
                    systemImage: snapshot.repeatMode == .one ? "repeat.1" : "repeat",
                    help: "Repeat",
                    isOn: snapshot.repeatMode.map { $0 != .off },
                    onColor: source.player.accentColor
                ) { send(.cycleRepeat) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func send(_ command: PlayerCommand) {
        Task { await source.perform(command) }
    }
}

/// Shows its content, or keeps the same space empty.
private struct ToggleSlot<Content: View>: View {
    let isAvailable: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .opacity(isAvailable ? 1 : 0)
            .disabled(!isAvailable)
    }
}

private struct VolumeSlider: View {
    let source: MediaPlayerSource
    let volume: Double

    @State private var dragVolume: Double?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(get: { dragVolume ?? volume }, set: { dragVolume = $0 }),
                in: 0...100,
                onEditingChanged: { isDragging in
                    guard !isDragging, let target = dragVolume else { return }
                    Task {
                        await source.perform(.setVolume(target))
                        dragVolume = nil
                    }
                }
            )
            .controlSize(.mini)
            .tint(.white)
            .frame(width: 64)
        }
        .help("Volume")
    }
}

private struct ControlButton: View {
    let systemImage: String
    let help: String
    /// For toggles (shuffle, repeat): whether it's on. `nil` for plain buttons.
    var isOn: Bool?
    /// The color while on, like the player app itself shows it.
    var onColor: Color = .primary
    let action: () -> Void

    private var style: AnyShapeStyle {
        switch isOn {
        case true?: AnyShapeStyle(onColor)
        case false?: AnyShapeStyle(.secondary)
        case nil: AnyShapeStyle(.primary)
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct AppIconButton: View {
    let source: MediaPlayerSource
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let icon = source.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Text(source.player.displayName).font(.caption)
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Explains what's missing when EasyNotch isn't (yet) allowed to control the player.
private struct PermissionHint: View {
    let source: MediaPlayerSource

    var body: some View {
        switch source.permission {
        case .notDetermined:
            HStack(spacing: 8) {
                Text("Allow control to use the buttons and see artwork.")
                    .lineLimit(1)
                Button("Allow…") { Task { await source.requestPermission() } }
                    .controlSize(.mini)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .denied:
            HStack(spacing: 8) {
                Text("Control of \(source.player.displayName) is turned off.")
                Button("Open System Settings") { MediaPlayerSource.openAutomationSettings() }
                    .controlSize(.mini)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .granted, .unknown, .playerNotRunning:
            EmptyView()
        }
    }
}

private struct NothingPlayingView: View {
    let sources: [MediaPlayerSource]

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.title2)
            Text("Nothing playing")
                .font(.headline)
            HStack {
                ForEach(sources.filter(\.isInstalled), id: \.player) { source in
                    Button("Open \(source.player.displayName)") { source.openApp() }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
