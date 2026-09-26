import SwiftUI

/// The Battery tab: a gauge with the charge, what the battery is doing, and details about the
/// charger and the battery's health.
struct BatteryView: View {
    @Environment(BatteryService.self) private var battery

    var body: some View {
        if let snapshot = battery.snapshot {
            HStack(spacing: 28) {
                BatteryGauge(snapshot: snapshot)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 10) {
                    Text(snapshot.statusText)
                        .font(.headline)
                        .lineLimit(2)
                    VStack(alignment: .leading, spacing: 6) {
                        if let watts = snapshot.adapterWatts {
                            Detail(symbol: "powerplug.fill", text: "\(watts) W charger connected")
                        }
                        if let health = snapshot.healthPercent {
                            let cycles = snapshot.cycleCount.map { " · \($0) cycles" } ?? ""
                            Detail(symbol: "heart.fill", text: "Battery health \(health)%\(cycles)")
                        }
                        if snapshot.isLowPowerMode {
                            Detail(symbol: "leaf.fill", text: "Low Power Mode is on")
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 36)
            .onAppear { battery.refresh() }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "powerplug")
                    .font(.title2)
                Text("This Mac doesn't have a battery")
                    .font(.headline)
                Text("It runs on power from the wall.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A ring that fills with the charge, colored green when charging, red when low.
private struct BatteryGauge: View {
    let snapshot: BatterySnapshot

    @Environment(BatteryService.self) private var battery

    private var color: Color {
        if battery.isLow || snapshot.percent <= 10 { return .red }
        if snapshot.isPluggedIn { return .green }
        return .white
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 8)
            Circle()
                .trim(from: 0, to: Double(snapshot.percent) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: snapshot.symbolName)
                    .font(.title3)
                    .foregroundStyle(color)
                Text("\(snapshot.percent)%")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

private struct Detail: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .frame(width: 16)
        }
    }
}
