import SwiftUI

/// The open notch: a header strip level with the notch (tabs on the left, gear on the
/// right, a gap in the middle where the hardware notch hides everything), and the selected
/// module below. Files dropped anywhere on it go onto the shelf.
struct ExpandedView: View {
    let viewModel: NotchViewModel

    @Environment(ShelfStore.self) private var shelf

    /// Up to this many tabs sit left of the notch. With more, they split across both sides,
    /// because six tabs don't fit on one side at small sizes.
    private static let tabsOnOneSide = 3

    var body: some View {
        let notch = viewModel.geometry.notchRect
        let modules = viewModel.visibleModules
        let leftCount = modules.count <= Self.tabsOnOneSide ? modules.count : (modules.count + 1) / 2

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabs(Array(modules.prefix(leftCount)))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Nothing can be seen here: it's behind the hardware notch.
                Color.clear.frame(width: notch.width)

                HStack(spacing: 4) {
                    tabs(Array(modules.dropFirst(leftCount)))
                    Button {
                        viewModel.showSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: notch.height)
            .padding(.horizontal, 16)

            Group {
                switch viewModel.currentModule {
                case .music: MusicView()
                case .pomodoro: PomodoroView()
                case .shelf: ShelfView()
                case .calendar: CalendarView()
                case .battery: BatteryView()
                case .system: SystemView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        // The whole open notch is a drop target, so you don't have to aim for the shelf.
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty, viewModel.visibleModules.contains(.shelf) else { return false }
            shelf.add(files)
            viewModel.selectedModule = .shelf
            return true
        } isTargeted: { isTargeted in
            let shelfIsOn = viewModel.visibleModules.contains(.shelf)
            shelf.isDropTargeted = isTargeted && shelfIsOn
            if isTargeted, shelfIsOn { viewModel.selectedModule = .shelf }
        }
    }
}

extension ExpandedView {
    private func tabs(_ modules: [NotchModule]) -> some View {
        HStack(spacing: 4) {
            ForEach(modules) { module in
                TabButton(module: module, isSelected: module == viewModel.currentModule) {
                    viewModel.selectedModule = module
                }
            }
        }
    }
}

private struct TabButton: View {
    let module: NotchModule
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.notchAccent) private var accent
    @Environment(\.hasCustomNotchAccent) private var hasCustomAccent

    /// Soft white by default, as always; tinted when you pick an accent color.
    private var highlight: Color {
        hasCustomAccent ? accent.opacity(0.45) : .white.opacity(0.18)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: module.systemImage)
                .frame(width: 32, height: 24)
                .background(isSelected ? highlight : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(module.title)
    }
}
