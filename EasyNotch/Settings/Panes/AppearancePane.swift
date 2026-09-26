import AppKit
import SwiftUI

/// How the notch moves, and its accent color.
struct AppearancePane: View {
    @Bindable var settings: AppSettings

    private var chosenAnimation: NotchAnimation {
        NotchAnimation(rawValue: settings.animationStyle) ?? .snappy
    }

    var body: some View {
        Form {
            Section {
                Picker("Style", selection: $settings.animationStyle) {
                    ForEach(NotchAnimation.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(chosenAnimation.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    Text("“Reduce motion” is on in macOS's Accessibility settings, so the notch uses Minimal.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Animation")
            }

            Section {
                HStack(spacing: 10) {
                    ForEach(NotchAccent.choices, id: \.name) { choice in
                        AccentSwatch(
                            color: NotchAccent.color(named: choice.name),
                            title: choice.title,
                            isSelected: settings.accentColor == choice.name
                        ) {
                            settings.accentColor = choice.name
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent color")
            } footer: {
                Text("Used for the selected tab, selected shelf files, and drop highlights. System follows the accent color in macOS settings.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

private struct AccentSwatch: View {
    let color: Color
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .padding(3)
                .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
