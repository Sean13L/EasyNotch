import SwiftUI

/// A track's cover art, or a music-note placeholder when there isn't one (yet).
struct MusicArtwork: View {
    let image: NSImage?
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.white.opacity(0.08))
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension MediaPlayer {
    /// The app's brand color, used for the "playing" indicator.
    var accentColor: Color {
        switch self {
        case .spotify: Color(red: 0.12, green: 0.84, blue: 0.38)
        case .appleMusic: Color(red: 0.98, green: 0.24, blue: 0.34)
        }
    }
}
