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

            VStack(alignment: .leading, spacing: 8) {
                header
                if let snapshot = source.snapshot {
                    Scrubber(source: source, snapshot: snapshot)
                    Controls(source: source, snapshot: snapshot)
                }
                PermissionHint(source: source)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.snapshot?.title ?? "\(source.player.displayName) is open")
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
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

/// Elapsed time, a draggable progress bar, and time remaining.
private struct Scrubber: View {
    let source: MediaPlayerSource
    let snapshot: PlayerSnapshot

    @State private var dragPosition: Double?

    var body: some View {
        if let duration = snapshot.duration, duration > 0, snapshot.position != nil {
            SecondsTimeline(isRunning: snapshot.isPlaying && dragPosition == nil) { now in
                let elapsed = dragPosition ?? snapshot.elapsed(at: now) ?? 0
                HStack(spacing: 8) {
                    Text(PlayerSnapshot.clock(elapsed))
                        .frame(width: 40, alignment: .trailing)
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
                        .frame(width: 44, alignment: .leading)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct Controls: View {
    let source: MediaPlayerSource
    let snapshot: PlayerSnapshot

    @State private var dragVolume: Double?

    var body: some View {
        HStack(spacing: 14) {
            if let shuffle = snapshot.shuffle {
                ControlButton(systemImage: "shuffle", help: "Shuffle", isOn: shuffle) {
                    send(.toggleShuffle)
                }
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
            if let repeatMode = snapshot.repeatMode {
                ControlButton(
                    systemImage: repeatMode == .one ? "repeat.1" : "repeat",
                    help: "Repeat",
                    isOn: repeatMode != .off
                ) { send(.cycleRepeat) }
            }

            Spacer(minLength: 0)

            if let volume = snapshot.volume {
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
                    .frame(width: 80)
                }
            }
        }
    }

    private func send(_ command: PlayerCommand) {
        Task { await source.perform(command) }
    }
}

private struct ControlButton: View {
    let systemImage: String
    let help: String
    var isOn: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn == false ? .secondary : .primary)
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
                Text("Allow EasyNotch to control \(source.player.displayName) to use the buttons and see artwork.")
                    .lineLimit(2)
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
