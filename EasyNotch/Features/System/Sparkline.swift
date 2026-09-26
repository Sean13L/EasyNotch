import SwiftUI

/// A tiny line chart of recent values, newest on the right.
struct Sparkline: View {
    let values: [Double]
    /// The value at the top of the chart; nil scales to the largest value shown.
    var maximum: Double?
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let top = max(maximum ?? values.max() ?? 1, .leastNonzeroMagnitude)
            let step = size.width / CGFloat(SystemMonitor.historyLength - 1)
            // Right-align, so the chart fills in from the right as samples arrive.
            let startX = size.width - step * CGFloat(values.count - 1)

            var line = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(
                    x: startX + step * CGFloat(index),
                    y: size.height - size.height * CGFloat(min(value / top, 1))
                )
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: startX, y: size.height))
            fill.closeSubpath()

            context.fill(fill, with: .color(color.opacity(0.18)))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
    }
}
