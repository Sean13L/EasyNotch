import SwiftUI

/// The Claude tab: the front permission request with Allow and Deny, and the usage bars.
struct ClaudeView: View {
    /// Opens the Settings window (the same route as the gear button).
    let onShowSettings: () -> Void

    @Environment(ClaudeService.self) private var claude

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch claude.setupStatus {
            case .disconnected:
                notice("Claude Code isn't connected.", button: "Open Settings")
            case .needsReconnect:
                notice("Claude Code's settings changed. Reconnect in Settings.", button: "Open Settings")
            case .connected:
                if let request = claude.pending.first {
                    RequestPanel(request: request, count: claude.pending.count, claude: claude)
                        .id(request.id)
                } else {
                    Text("No requests waiting.")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeUsageView.secondary)
                }
                if let usage = claude.usage {
                    ClaudeUsageView(usage: usage)
                } else {
                    Text("Usage appears after your next Claude Code message.")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeUsageView.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func notice(_ text: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.system(size: 12))
            Button(button, action: onShowSettings)
        }
    }
}

/// One waiting request. Its own view so the "just became the front" guard state resets for
/// each new request (the parent gives it `.id(request.id)`).
private struct RequestPanel: View {
    let request: ClaudeRequest
    let count: Int
    let claude: ClaudeService

    /// Once true, the guard has passed and nothing needs to tick any more.
    @State private var ready = false

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
                buttons(enabled: true)
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let ok = claude.canAnswer(request.id)
                    buttons(enabled: ok)
                        .onChange(of: ok) { _, now in if now { ready = true } }
                }
            }
        }
    }

    private func buttons(enabled: Bool) -> some View {
        HStack {
            Spacer()
            Button("Deny") { claude.deny(request.id) }
                .keyboardShortcut(.cancelAction)
            Button("Allow") { claude.allow(request.id) }
                .keyboardShortcut(.defaultAction)
        }
        .disabled(!enabled)
    }
}
