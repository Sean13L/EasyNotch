import SwiftUI

/// What the Claude pill shows: for a permission request, the terminal icon with a red count
/// badge and the tool name; for a finished reply, a green check and "Done".
struct ClaudeCompactView: View {
    @Environment(ClaudeService.self) private var claude

    var body: some View {
        if let request = claude.pending.first {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                    .overlay(alignment: .topTrailing) { badge.offset(x: 8, y: -6) }
                    .padding(.trailing, 6)
                Text(request.tool)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Claude Code: \(claude.pending.count) waiting, \(request.tool)")
        } else if claude.finished != nil {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Claude Code finished. Hover to reply.")
        }
    }

    private var badge: some View {
        Text("\(claude.pending.count)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 14, minHeight: 14)
            .background(Capsule().fill(.red))
    }
}
