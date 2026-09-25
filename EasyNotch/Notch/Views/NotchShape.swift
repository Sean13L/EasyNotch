import SwiftUI

/// The notch outline. At the top, concave "ears" flare outward to meet the screen edge;
/// at the bottom, the corners are rounded. Both radii are animatable, so the shape morphs
/// smoothly as the notch grows.
///
/// The ears stick out `topRadius` beyond the body on each side, so the frame you give this
/// shape should be the body's width plus `2 * topRadius`.
///
/// `nonisolated` because SwiftUI may compute shape paths off the main thread.
nonisolated struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + topRadius     // the body's left wall
        let right = rect.maxX - topRadius    // the body's right wall
        let bottom = min(bottomRadius, (right - left) / 2, rect.height - topRadius)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Left ear: curve from the top edge in and down to the left wall.
        path.addQuadCurve(
            to: CGPoint(x: left, y: rect.minY + topRadius),
            control: CGPoint(x: left, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: left + bottom, y: rect.maxY),
            control: CGPoint(x: left, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: right, y: rect.maxY - bottom),
            control: CGPoint(x: right, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY + topRadius))
        // Right ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: right, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
