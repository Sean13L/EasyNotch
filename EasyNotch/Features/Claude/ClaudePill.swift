import SwiftUI

/// The black bubble beside the notch that holds a waiting Claude Code request. Flat on top
/// like the notch, rounded below, so it looks like a small notch of its own.
struct ClaudePill: View {
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                .fill(.black)
            ClaudeCompactView()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
        }
    }
}
