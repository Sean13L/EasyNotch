import SwiftUI

/// What's playing, beside the closed notch: cover art on the left wing and bouncing audio bars
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
                AudioBars(isPlaying: source.snapshot?.isPlaying == true, color: source.player.accentColor)
                    .frame(width: 22, height: 14)
            }
        }
    }
}
