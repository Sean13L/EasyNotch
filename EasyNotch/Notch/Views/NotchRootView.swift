import SwiftUI

/// Everything drawn inside the notch window: the black notch shape, sized and animated for
/// what's showing (closed, compact with a live activity, or open), with that state's content
/// on top.
struct NotchRootView: View {
    let viewModel: NotchViewModel

    var body: some View {
        let geometry = viewModel.geometry
        let presentation = viewModel.presentation
        let animation = viewModel.animationStyle
        let style = NotchShapeLayout(presentation, geometry: geometry)
        let rect = geometry.localRect(style.rect)

        ZStack(alignment: .top) {
            NotchShape(topRadius: style.ear, bottomRadius: style.corner)
                .fill(.black)
                .frame(width: rect.width + style.ear * 2, height: rect.height)
                .shadow(color: .black.opacity(presentation == .open ? 0.45 : 0), radius: 12, y: 6)

            switch presentation {
            case .open:
                ExpandedView(viewModel: viewModel)
                    .frame(width: rect.width, height: rect.height)
                    .transition(contentTransition)
            case let .compact(activity):
                CompactView(activity: activity, notchWidth: geometry.notchRect.width)
                    .frame(width: rect.width, height: rect.height)
                    .transition(contentTransition)
            case .closed:
                EmptyView()
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .frame(width: geometry.panelFrame.width, height: geometry.panelFrame.height)
        .animation(presentation == .open ? animation.opening : animation.closing, value: presentation)
        .environment(\.colorScheme, .dark)
        .environment(\.notchAccent, NotchAccent.color(named: viewModel.accentName))
        .environment(\.hasCustomNotchAccent, viewModel.accentName != "system")
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.1))
        )
    }
}

/// The shape's size and corner rounding for each presentation.
private struct NotchShapeLayout {
    let rect: CGRect
    let ear: CGFloat
    let corner: CGFloat

    init(_ presentation: NotchPresentation, geometry: NotchGeometry) {
        switch presentation {
        case .closed:
            // No ears, and bottom corners rounder than the hardware notch's, so the shape stays
            // completely hidden inside the notch cutout.
            (rect, ear, corner) = (geometry.notchRect, 0, 12)
        case .compact:
            let wing = (geometry.compactRect.width - geometry.notchRect.width) / 2
            (rect, ear, corner) = (geometry.compactRect, min(6, wing), 12)
        case .open:
            (rect, ear, corner) = (geometry.openRect, 10, 24)
        }
    }
}
