import SwiftUI

/// Claude finished a reply: the end of its message, and a box to type what to do next.
/// Send makes Claude keep going with your text; Done lets the session stop.
struct ClaudeFinishedPanel: View {
    let finished: ClaudeFinished

    @Environment(ClaudeService.self) private var claude
    @State private var reply = ""

    private var trimmedReply: String { reply.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(finished.project) · finished")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text(finished.message)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeUsageView.secondary)
                .lineLimit(3)
                .truncationMode(.head)  // the end of a reply is where its question usually is
                .help(finished.message)
            HStack {
                TextField("Next steps for Claude…", text: $reply)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .accessibilityLabel("Reply to Claude")
                    .onSubmit { if !trimmedReply.isEmpty { claude.sendReply(trimmedReply) } }
                Button("Done") { claude.dismissFinished() }
                Button("Send") { claude.sendReply(trimmedReply) }
                    .disabled(trimmedReply.isEmpty)
            }
        }
    }
}
