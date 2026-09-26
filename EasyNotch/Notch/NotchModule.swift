/// The features that can appear as tabs in the expanded notch, in default tab order.
enum NotchModule: String, CaseIterable, Identifiable, Codable {
    case music
    case shelf
    case pomodoro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: "Music"
        case .shelf: "Shelf"
        case .pomodoro: "Pomodoro"
        }
    }

    /// SF Symbol shown on the tab.
    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .shelf: "tray.full"
        case .pomodoro: "timer"
        }
    }

    /// Turns a saved tab order into a clean one: every module exactly once, unknown names
    /// dropped, and any missing module (e.g. one added in a later version) added at the end.
    static func ordered(from savedOrder: [String]) -> [NotchModule] {
        var result: [NotchModule] = []
        for name in savedOrder {
            if let module = NotchModule(rawValue: name), !result.contains(module) {
                result.append(module)
            }
        }
        result += allCases.filter { !result.contains($0) }
        return result
    }

    /// The order after dragging `dragged` onto `target`: it takes the target's place, and the
    /// tabs in between shift over by one (like moving a file in a list).
    static func reordered(_ modules: [NotchModule], moving dragged: NotchModule, onto target: NotchModule) -> [NotchModule] {
        guard dragged != target,
              let from = modules.firstIndex(of: dragged),
              let to = modules.firstIndex(of: target)
        else { return modules }
        var result = modules
        result.remove(at: from)
        result.insert(dragged, at: to)
        return result
    }

    /// The tabs to show, in order. If every tab is turned off, the first one stays, because the
    /// notch needs at least one.
    static func visible(order savedOrder: [String], hidden: [String]) -> [NotchModule] {
        let ordered = ordered(from: savedOrder)
        let visible = ordered.filter { !hidden.contains($0.rawValue) }
        return visible.isEmpty ? Array(ordered.prefix(1)) : visible
    }
}
