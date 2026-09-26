import SwiftUI

/// The System tab: CPU, memory, and network tiles, plus free disk space and temperature state.
/// Measuring only runs while this tab is on screen.
struct SystemView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Tile(title: "CPU", symbol: "cpu") {
                    Text("\(Int((monitor.cpu * 100).rounded()))%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Sparkline(values: monitor.cpuHistory, maximum: 1, color: cpuColor)
                }
                Tile(title: "Memory", symbol: "memorychip") {
                    Text(SystemMath.sizeText(Double(monitor.memoryUsed)))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("of \(SystemMath.sizeText(Double(monitor.memoryTotal))) · pressure \(monitor.memoryPressure.rawValue.lowercased())")
                        .font(.caption2)
                        .foregroundStyle(pressureColor)
                    ProgressView(value: Double(monitor.memoryUsed), total: Double(max(monitor.memoryTotal, 1)))
                        .tint(pressureColor)
                }
                Tile(title: "Network", symbol: "network") {
                    HStack(spacing: 10) {
                        Label(SystemMath.rateText(monitor.download), systemImage: "arrow.down")
                        Label(SystemMath.rateText(monitor.upload), systemImage: "arrow.up")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    Sparkline(values: monitor.downloadHistory, color: .cyan)
                }
            }
            HStack(spacing: 16) {
                Label("\(SystemMath.sizeText(Double(monitor.diskFree))) free on disk", systemImage: "internaldrive")
                Label(thermalText, systemImage: "thermometer.medium")
                    .foregroundStyle(monitor.thermalState == .nominal ? Color.secondary : .orange)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .onAppear { monitor.beginWatching() }
        .onDisappear { monitor.endWatching() }
    }

    private var cpuColor: Color {
        monitor.cpu > 0.8 ? .orange : .green
    }

    private var pressureColor: Color {
        switch monitor.memoryPressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }

    private var thermalText: String {
        switch monitor.thermalState {
        case .nominal: "Temperature normal"
        case .fair: "Running warm"
        case .serious: "Running hot, may slow down"
        case .critical: "Very hot, slowing down"
        @unknown default: "Temperature unknown"
        }
    }
}

private struct Tile<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
