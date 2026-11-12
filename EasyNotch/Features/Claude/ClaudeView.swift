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
                notice("Connect Claude Code to answer permission requests from the notch.", button: "Open Settings")
            case .needsReconnect:
                notice("EasyNotch moved. Reconnect in Settings.", button: "Open Settings")
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
                    Text("Usage appears after your next Claude message (Pro, Max, and Ultra plans).")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeUsageView.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // This view exists only while an open notch shows the Claude tab, so this is when
        // its requests have really been seen.
        .onAppear { claude.tabAppeared() }
        .onDisappear { claude.tabDisappeared() }
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
                        .onChange(of: ok, initial: true) { _, now in if now { ready = true } }
                }
            }
        }
    }

    private func buttons(enabled: Bool) -> some View {
        HStack {
            Spacer()
            // No keyboard shortcuts: the notch never takes keyboard focus (NotchPanel), and a
            // stray Return must never approve anything. Click to answer.
            Button("Deny") { claude.deny(request.id) }
            Button("Allow") { claude.allow(request.id) }
        }
        .disabled(!enabled)
    }
}
