import SwiftUI

/// Which tabs the notch shows, in what order, and which opens first.
struct ModulesPane: View {
    @Bindable var settings: AppSettings

    /// The row a tab is being dragged over, to highlight it.
    @State private var dropTarget: NotchModule?

    private var ordered: [NotchModule] {
        NotchModule.ordered(from: settings.moduleOrder)
    }

    private var visibleCount: Int {
        NotchModule.visible(order: settings.moduleOrder, hidden: settings.hiddenModules).count
    }

    var body: some View {
        Form {
            Section {
                ForEach(Array(ordered.enumerated()), id: \.element) { index, module in
                    ModuleRow(
                        module: module,
                        isOn: isOnBinding(for: module),
                        canTurnOff: visibleCount > 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < ordered.count - 1,
                        isDropTarget: dropTarget == module,
                        move: { offset in move(module, by: offset) }
                    )
                    // Each row can be dragged, and each row accepts a dragged tab. (A Form can't
                    // use SwiftUI's built-in list reordering, so this does it by hand.)
                    .draggable(module.rawValue) {
                        Label(module.title, systemImage: module.systemImage)
                            .padding(6)
                    }
                    .dropDestination(for: String.self) { names, _ in
                        guard let dragged = names.first.flatMap(NotchModule.init(rawValue:)) else { return false }
                        settings.moduleOrder = NotchModule.reordered(ordered, moving: dragged, onto: module).map(\.rawValue)
                        return true
                    } isTargeted: { isTargeted in
                        if isTargeted {
                            dropTarget = module
                        } else if dropTarget == module {
                            dropTarget = nil
                        }
                    }
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("Drag a tab onto another to move it there, or use the arrows. Turning a tab off also stops its live activity beside the notch, and for the Shelf, opening when you drag files.")
            }

            Section {
                Picker("Tab that opens first", selection: $settings.defaultModule) {
                    Text("The last one used").tag("lastUsed")
                    ForEach(ordered) { module in
                        Text(module.title).tag(module.rawValue)
                    }
                }
            } footer: {
                Text("A running timer, music beside the notch, or a file drag still opens its own tab.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Modules")
    }

    private func isOnBinding(for module: NotchModule) -> Binding<Bool> {
        Binding(
            get: { !settings.hiddenModules.contains(module.rawValue) },
            set: { isOn in
                var hidden = settings.hiddenModules.filter { $0 != module.rawValue }
                if !isOn { hidden.append(module.rawValue) }
                settings.hiddenModules = hidden
            }
        )
    }

    private func move(_ module: NotchModule, by offset: Int) {
        var modules = ordered
        guard let index = modules.firstIndex(of: module) else { return }
        let target = index + offset
        guard modules.indices.contains(target) else { return }
        modules.swapAt(index, target)
        settings.moduleOrder = modules.map(\.rawValue)
    }
}

private struct ModuleRow: View {
    let module: NotchModule
    @Binding var isOn: Bool
    let canTurnOff: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isDropTarget: Bool
    let move: (Int) -> Void

    @Environment(\.notchAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to reorder")
            Label(module.title, systemImage: module.systemImage)
            Spacer()
            Button { move(-1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)
                .help("Move up")
            Button { move(1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)
                .help("Move down")
            Toggle("Show \(module.title)", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isOn && !canTurnOff)
                .help(isOn && !canTurnOff ? "At least one tab stays on" : "")
        }
        .contentShape(Rectangle())  // the whole row, including gaps, starts a drag
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTarget ? accent.opacity(0.25) : .clear)
                .padding(-4)
        )
    }
}
