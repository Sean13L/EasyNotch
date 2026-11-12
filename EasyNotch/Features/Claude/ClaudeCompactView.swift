import SwiftUI

/// A Claude Code permission request beside the closed notch: the terminal icon and how many
/// are waiting on the left, the front request's summary on the right.
struct ClaudeCompactView: View {
    enum Side {
        case leading
        case trailing
    }

    let side: Side

    @Environment(ClaudeService.self) private var claude

    var body: some View {
        if let request = claude.pending.first {
            switch side {
            case .leading:
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(claude.pending.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            case .trailing:
                Text(request.summary)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
            }
        }
    }
}
