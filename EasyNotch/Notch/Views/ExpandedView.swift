import SwiftUI

/// The open notch: a header strip level with the notch (tabs on the left, gear on the
/// right, a gap in the middle where the hardware notch hides everything), and the selected
/// module below.
struct ExpandedView: View {
    let viewModel: NotchViewModel

    var body: some View {
        let notch = viewModel.geometry.notchRect

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(NotchModule.allCases) { module in
                        TabButton(module: module, isSelected: module == viewModel.selectedModule) {
                            viewModel.selectedModule = module
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Nothing can be seen here: it's behind the hardware notch.
                Color.clear.frame(width: notch.width)

                Button {
                    viewModel.showSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: notch.height)
            .padding(.horizontal, 16)

            Group {
                switch viewModel.selectedModule {
                case .music: MusicView()
                case .pomodoro: PomodoroView()
                case .shelf: ModulePlaceholder(module: viewModel.selectedModule)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }
}

private struct TabButton: View {
    let module: NotchModule
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: module.systemImage)
                .frame(width: 32, height: 24)
                .background(isSelected ? .white.opacity(0.18) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(module.title)
    }
}

/// Stand-in content until each module is built.
private struct ModulePlaceholder: View {
    let module: NotchModule

    private var phase: Int {
        switch module {
        case .music: 3
        case .shelf, .pomodoro: 4
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: module.systemImage)
                .font(.title2)
            Text(module.title)
                .font(.headline)
            Text("Coming in Phase \(phase)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
