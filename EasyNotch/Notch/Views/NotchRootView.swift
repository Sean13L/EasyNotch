import SwiftUI

/// Everything drawn inside the notch window: the black notch shape, sized and animated for
/// the current state, with the expanded content on top when open.
struct NotchRootView: View {
    let viewModel: NotchViewModel

    private var isOpen: Bool { viewModel.state == .open }

    var body: some View {
        let geometry = viewModel.geometry
        let rect = geometry.localRect(isOpen ? geometry.openRect : geometry.notchRect)
        // Closed: no ears, and bottom corners rounder than the hardware notch's, so the shape
        // stays completely hidden inside the notch cutout.
        let ear: CGFloat = isOpen ? 10 : 0
        let corner: CGFloat = isOpen ? 24 : 12

        ZStack(alignment: .top) {
            NotchShape(topRadius: ear, bottomRadius: corner)
                .fill(.black)
                .frame(width: rect.width + ear * 2, height: rect.height)
                .shadow(color: .black.opacity(isOpen ? 0.45 : 0), radius: 12, y: 6)

            if isOpen {
                ExpandedView(viewModel: viewModel)
                    .frame(width: rect.width, height: rect.height)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.08)),
                        removal: .opacity.animation(.easeIn(duration: 0.1))
                    ))
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .frame(width: geometry.panelFrame.width, height: geometry.panelFrame.height)
        // Closing uses a quicker, less bouncy spring than opening, so it gets out of the way.
        .animation(
            isOpen ? .spring(response: 0.38, dampingFraction: 0.8) : .spring(response: 0.28, dampingFraction: 0.9),
            value: isOpen
        )
        .environment(\.colorScheme, .dark)
    }
}
