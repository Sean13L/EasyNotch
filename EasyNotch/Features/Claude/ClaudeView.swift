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
                    ClaudeRequestPanel(request: request, count: claude.pending.count)
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
