import SwiftUI

/// The small card that drops down when you hover the Claude pill: the front permission
/// request, or else the finished reply, so you can answer without opening the whole notch.
struct ClaudeCardView: View {
    /// The notch's height; the card's content starts below it.
    let topInset: CGFloat
    /// Closes the card once nothing is left to answer.
    let onDone: () -> Void

    @Environment(ClaudeService.self) private var claude

    var body: some View {
        VStack {
            // Permission requests first: they're blocking Claude mid-task.
            if let request = claude.pending.first {
                ClaudeRequestPanel(request: request, count: claude.pending.count)
                    .id(request.id)
            } else if let finished = claude.finished {
                ClaudeFinishedPanel(finished: finished)
                    .id(finished.id)
            }
        }
        .padding(.top, topInset + 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: claude.pending.isEmpty && claude.finished == nil, initial: true) { _, empty in
            if empty { onDone() }
        }
        .onAppear { claude.finishedCardVisible(true) }
        .onDisappear { claude.finishedCardVisible(false) }
    }
}
