import AppKit
import SwiftUI

/// Little equalizer bars that bounce while music plays and settle when it pauses.
///
/// The motion runs in Core Animation, which macOS drives in its own graphics process, so the
/// bars keep moving without EasyNotch spending any CPU on them.
struct AudioBars: NSViewRepresentable {
    let isPlaying: Bool
    let color: Color

    func makeNSView(context: Context) -> AudioBarsView {
        AudioBarsView()
    }

    func updateNSView(_ view: AudioBarsView, context: Context) {
        view.color = NSColor(color)
        view.isAnimating = isPlaying
    }
}

final class AudioBarsView: NSView {
    var color: NSColor = .white {
        didSet { bars.forEach { $0.backgroundColor = color.cgColor } }
    }

    var isAnimating = false {
        didSet {
            if isAnimating != oldValue { updateAnimations() }
        }
    }

    private let bars: [CALayer] = (0..<4).map { _ in CALayer() }
    private let barWidth: CGFloat = 3
    private let gap: CGFloat = 2
    /// The height the current animations were built for.
    private var animatedHeight: CGFloat = 0

    /// Each bar's height over one loop, as a fraction of the view's height. Every bar gets a
    /// different pattern and speed, so they never move in lockstep and look like real audio.
    private static let patterns: [[CGFloat]] = [
        [0.35, 0.90, 0.50, 1.00, 0.40, 0.75, 0.35],
        [0.80, 0.40, 1.00, 0.55, 0.90, 0.30, 0.80],
        [0.50, 1.00, 0.35, 0.70, 0.45, 0.95, 0.50],
        [0.90, 0.45, 0.75, 0.30, 1.00, 0.55, 0.90],
    ]
    private static let loopDurations: [CFTimeInterval] = [1.30, 1.10, 1.45, 1.20]
    /// Height of the bars while paused.
    private static let restingFraction: CGFloat = 0.3

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for bar in bars {
            bar.backgroundColor = color.cgColor
            layer?.addSublayer(bar)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("AudioBarsView is only created in code")
    }

    override func layout() {
        super.layout()
        let totalWidth = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * gap
        var x = (bounds.width - totalWidth) / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)  // place the bars without animating
        for bar in bars {
            bar.position = CGPoint(x: x + barWidth / 2, y: bounds.midY)
            bar.bounds.size = CGSize(width: barWidth, height: bounds.height * Self.restingFraction)
            bar.cornerRadius = barWidth / 2
            x += barWidth + gap
        }
        CATransaction.commit()
        // The animated heights depend on our size, so rebuild them only if it changed;
        // rebuilding restarts the motion, which would look like a hiccup.
        if bounds.height != animatedHeight {
            updateAnimations()
        }
    }

    private func updateAnimations() {
        let height = bounds.height
        guard height > 0 else { return }  // not laid out yet; layout() will call back
        animatedHeight = height

        for (index, bar) in bars.enumerated() {
            let wasBouncing = bar.animation(forKey: "bounce") != nil
            let currentHeight = bar.presentation()?.bounds.size.height
            bar.removeAnimation(forKey: "bounce")

            guard isAnimating else {
                // Ease down to the resting height instead of snapping there.
                if wasBouncing, let currentHeight {
                    let settle = CABasicAnimation(keyPath: "bounds.size.height")
                    settle.fromValue = currentHeight
                    settle.toValue = bar.bounds.height
                    settle.duration = 0.25
                    settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    bar.add(settle, forKey: "settle")
                }
                continue
            }

            let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
            animation.values = Self.patterns[index].map { $0 * height }
            animation.duration = Self.loopDurations[index]
            animation.calculationMode = .cubic  // smooth curves between the heights
            animation.repeatCount = .infinity
            bar.add(animation, forKey: "bounce")
        }
    }
}
