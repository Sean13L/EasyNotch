import SwiftUI

/// Claude Code's 5-hour and weekly usage as two bars, with when each resets and how fresh the
/// numbers are.
struct ClaudeUsageView: View {
    let usage: ClaudeUsage

    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Redraws once a minute (and only while visible) so "resets in" and "updated" stay true.
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 6) {
                    if let window = usage.fiveHour {
                        row("5h", window, now: context.date)
                    }
                    if let window = usage.sevenDay {
                        row("Week", window, now: context.date)
                    }
                    Text(Self.updatedText(usage.updatedAt, now: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(Self.secondary)
                }
            }
        }
    }

    /// 70% white on the black notch is about 10:1, well above the 4.5:1 AA minimum.
    static let secondary = Color.white.opacity(0.7)

    private func row(_ label: String, _ window: UsageWindow, now: Date) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 34, alignment: .leading)
            ProgressView(value: min(max(window.usedPercentage, 0), 100), total: 100)
                .tint(accent)
                .accessibilityLabel("\(label) usage")
                .accessibilityValue("\(Int(window.usedPercentage.rounded())) percent")
            Text("\(Int(window.usedPercentage.rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 34, alignment: .trailing)
            Text(Self.resetText(window.resetsAt, now: now))
                .font(.system(size: 10))
                .foregroundStyle(Self.secondary)
                .frame(width: 92, alignment: .leading)
        }
    }

    /// "resets in 2h 10m", or the weekday ("resets Friday") when it is more than a day away.
    static func resetText(_ date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "resetting" }
        if seconds > 24 * 3600 {
            return "resets " + date.formatted(.dateTime.weekday(.wide))
        }
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        return hours > 0 ? "resets in \(hours)h \(minutes % 60)m" : "resets in \(minutes)m"
    }

    static func updatedText(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        return minutes < 1 ? "Updated just now" : "Updated \(minutes) min ago"
    }
}
