import SwiftUI

/// Which notch shape the Size pane is previewing.
enum SizePreview: Equatable {
    /// The open notch, for the width and height sliders.
    case expanded
    /// The closed notch with its live-activity wings, for the wing width slider.
    case compact
}

/// How big the notch gets when it opens, and how wide its live-activity wings are.
struct SizePane: View {
    @Bindable var settings: AppSettings
    /// Switches the notch preview to match the slider being dragged.
    let onPreviewChange: (SizePreview) -> Void

    var body: some View {
        Form {
            Section {
                SettingSlider(
                    title: "Width",
                    value: $settings.expandedWidth, setting: .expandedWidth, step: 10, unit: .points,
                    onEditingChanged: { if $0 { onPreviewChange(.expanded) } }
                )
                SettingSlider(
                    title: "Height",
                    value: $settings.expandedHeight, setting: .expandedHeight, step: 10, unit: .points,
                    onEditingChanged: { if $0 { onPreviewChange(.expanded) } }
                )
            } header: {
                Text("Expanded notch")
            } footer: {
                Text("The smallest sizes still leave room for every tab.")
            }

            Section {
                SettingSlider(
                    title: "Live activity width",
                    value: $settings.compactWingWidth, setting: .compactWingWidth, step: 2, unit: .points,
                    onEditingChanged: { if $0 { onPreviewChange(.compact) } }
                )
            } header: {
                Text("Closed notch")
            } footer: {
                Text("How far the closed notch widens on each side to show things like a running timer or what's playing. At 0 it stays exactly the size of the notch; content shrinks to fit narrow wings.")
            }

            Section {
                Text("While this pane is showing, the notch previews your changes: open while you adjust its size, and closed with its wings while you adjust the live activity width.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Size")
    }
}
