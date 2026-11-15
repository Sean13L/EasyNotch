import SwiftUI

/// One waiting request with Allow, Deny, and a note field to tell Claude why it was denied.
/// Shared by the Claude tab and the hover card. Give it `.id(request.id)` so the "just became
/// the front" guard state resets for each new request.
struct ClaudeRequestPanel: View {
    let request: ClaudeRequest
    let count: Int

    @Environment(ClaudeService.self) private var claude
    /// Once true, the guard has passed and nothing needs to tick any more.
    @State private var ready = false
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(request.project) · \(request.tool)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("1 of \(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeUsageView.secondary)
            }
            Text(request.summary)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(3)
                .help(request.summary)
                .accessibilityLabel(request.summary)
            // Answers are refused for a moment after a request becomes the front (see
            // `ClaudeService.answerGuard`). Time isn't observable, so tick only until it passes.
            if ready || claude.canAnswer(request.id) {
                controls(enabled: true)
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let ok = claude.canAnswer(request.id)
                    controls(enabled: ok)
                        .onChange(of: ok, initial: true) { _, now in if now { ready = true } }
                }
            }
        }
    }

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func controls(enabled: Bool) -> some View {
        HStack {
            TextField("Deny and tell Claude why…", text: $note)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .accessibilityLabel("Reason for denying")
                // Return only ever denies: a stray Return must never approve anything.
                .onSubmit { if enabled, !trimmedNote.isEmpty { claude.deny(request.id, note: trimmedNote) } }
            Button("Deny") { claude.deny(request.id, note: trimmedNote) }
            Button("Allow") { claude.allow(request.id) }
        }
        .disabled(!enabled)
    }
}
