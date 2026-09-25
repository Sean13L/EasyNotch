import SwiftUI

/// What's playing, beside the closed notch: cover art on the left wing and a pulsing waveform
/// in the player's color on the right one.
struct MusicCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(NowPlayingService.self) private var nowPlaying

    var body: some View {
        if let source = nowPlaying.active {
            switch side {
            case .leading:
                MusicArtwork(image: source.artwork, cornerRadius: 5)
                    .frame(width: 22, height: 22)
            case .trailing:
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(source.player.accentColor)
                    .symbolEffect(.pulse, isActive: source.snapshot?.isPlaying == true)
            }
        }
    }
}
