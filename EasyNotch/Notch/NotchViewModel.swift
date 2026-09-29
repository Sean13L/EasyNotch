import AppKit
import Observation

enum NotchState: Equatable {
    case closed
    case open
}

/// The state of one screen's notch. It turns pointer positions, clicks, and the keyboard
/// shortcut into open/closed decisions, following the timing and behavior in `AppSettings`.
@Observable
final class NotchViewModel {
    /// Why the notch is opening; decides which tab it shows.
    enum OpenReason {
        case pointer
        case fileDrag
        case shortcut
    }

    private(set) var state: NotchState = .closed
    private(set) var geometry: NotchGeometry
    /// The tab the user last picked. See `currentModule` for the one actually shown.
    var selectedModule: NotchModule = .music
    /// Set while the Size settings pane is showing, so you can watch the notch change as you
    /// drag its sliders. The pointer is ignored during a preview.
    private(set) var preview: SizePreview?
    /// True when the keyboard shortcut opened the notch. It then stays open while the pointer
    /// is elsewhere, until the pointer visits it and leaves, or you click outside it.
    private(set) var isHeldOpen = false

    /// The tab that was on screen when the notch last closed. Its live activity is preferred
    /// beside the closed notch (see `LiveActivity.resolve`).
    private(set) var lastViewedModule: NotchModule?

    /// Which live activity (if any) should show beside the closed notch, given the tab to
    /// prefer. Set by `AppServices`, so the notch never needs to know about individual features.
    @ObservationIgnored var liveActivityProvider: (NotchModule?) -> LiveActivity? = { _ in nil }
    /// Called after every state change; the window controller uses it to toggle click-through.
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
    /// Called whenever the notch opens (not for Settings previews), e.g. to mark alerts as seen.
    @ObservationIgnored var onOpen: (() -> Void)?
    /// Called when the gear button is pressed.
    @ObservationIgnored var onShowSettings: (() -> Void)?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var pendingTransition: Task<Void, Never>?
    @ObservationIgnored private var pendingTarget: NotchState?

    init(geometry: NotchGeometry, settings: AppSettings) {
        self.geometry = geometry
        self.settings = settings
    }

    func update(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    // MARK: - What's shown

    var liveActivity: LiveActivity? { liveActivityProvider(lastViewedModule) }

    var presentation: NotchPresentation {
        if state == .open { return .open }
        if preview == .compact {
            // Show the wings even when nothing is playing, so their width can be judged.
            return .compact(liveActivity ?? .placeholder)
        }
        if let liveActivity { return .compact(liveActivity) }
        return .closed
    }

    /// The tabs to show, in the user's order, without the ones turned off.
    var visibleModules: [NotchModule] {
        NotchModule.visible(order: settings.moduleOrder, hidden: settings.hiddenModules)
    }

    /// The tab on screen: the selected one, unless it has been turned off.
    var currentModule: NotchModule {
        let visible = visibleModules
        return visible.contains(selectedModule) ? selectedModule : visible[0]
    }

    var animationStyle: NotchAnimation {
        NotchAnimation.current(settingName: settings.animationStyle)
    }

    var accentName: String { settings.accentColor }

    // MARK: - Pointer

    func pointerMoved(to point: CGPoint) {
        guard preview == nil else { return }
        switch state {
        case .closed:
            // Mouse moves arrive constantly; skip the rest unless the pointer is near the notch.
            // (The compact hot zone always contains the plain one.)
            guard !settings.openOnClick, geometry.compactHotZone.contains(point) else {
                cancelPendingTransition()
                return
            }
            if activeHotZone.contains(point) {
                schedule(.open, after: settings.hoverDelay)
            } else {
                cancelPendingTransition()
            }
        case .open:
            if geometry.openRect.contains(point) {
                isHeldOpen = false  // the pointer arrived; normal rules from now on
                cancelPendingTransition()
            } else if !isHeldOpen {
                schedule(.closed, after: settings.closeDelay)
            }
        }
    }

    /// The mouse moved with its button held. A file drag near the notch opens it right away
    /// (no hover delay) on the Shelf tab. Other drags, like moving a window or selecting text,
    /// never open it, but can close it.
    func pointerDragged(to point: CGPoint, carryingFiles: Bool) {
        guard preview == nil else { return }
        switch state {
        case .closed:
            guard carryingFiles, settings.shelfOpenOnDrag, visibleModules.contains(.shelf),
                  geometry.dragHotZone.contains(point)
            else { return }
            cancelPendingTransition()
            open(.fileDrag)
        case .open:
            // Be forgiving while carrying files, so the notch doesn't close just before a drop.
            let keepOpen = carryingFiles ? geometry.openRect.union(geometry.dragHotZone) : geometry.openRect
            if keepOpen.contains(point) {
                cancelPendingTransition()
            } else if !isHeldOpen {
                schedule(.closed, after: settings.closeDelay)
            }
        }
    }

    /// A left click. In click mode, clicking the notch opens it. A click anywhere outside the
    /// open notch closes it right away.
    func mouseDown(at point: CGPoint) {
        guard preview == nil else { return }
        switch state {
        case .closed:
            if settings.openOnClick, activeHotZone.contains(point) {
                cancelPendingTransition()
                open(.pointer)
            }
        case .open:
            if !geometry.openRect.contains(point) { close() }
        }
    }

    /// A right click. Returns true if it's on the closed notch, which then shows its menu.
    /// A right click outside the open notch closes it, like a left click.
    func rightMouseDown(at point: CGPoint) -> Bool {
        guard preview == nil else { return false }
        switch state {
        case .closed:
            return activeHotZone.contains(point)
        case .open:
            if !geometry.openRect.contains(point) { close() }
            return false
        }
    }

    // MARK: - Actions

    /// The keyboard shortcut: opens the notch, or closes it if it's open.
    func toggleFromShortcut() {
        guard preview == nil else { return }
        cancelPendingTransition()
        if state == .open {
            close()
        } else {
            open(.shortcut)
            isHeldOpen = true
        }
    }

    func close() {
        guard preview == nil else { return }
        cancelPendingTransition()
        setState(.closed)
    }

    func setPreview(_ newPreview: SizePreview?) {
        guard newPreview != preview else { return }
        preview = newPreview
        cancelPendingTransition()
        setState(newPreview == .expanded ? .open : .closed)
    }

    func showSettings() {
        close()
        onShowSettings?()
    }

    // MARK: - Private

    /// The hover and click area: wider while a live activity shows its wings.
    private var activeHotZone: CGRect {
        liveActivity == nil ? geometry.hotZone : geometry.compactHotZone
    }

    private func open(_ reason: OpenReason) {
        selectedModule = openingModule(for: reason)
        setState(.open)
    }

    /// Which tab to show when opening, in order of priority:
    /// 1. a file drag → the Shelf
    /// 2. a live activity → its tab, like tapping the Dynamic Island
    /// 3. the "Tab that opens first" setting
    /// 4. the tab last used
    private func openingModule(for reason: OpenReason) -> NotchModule {
        let visible = visibleModules
        if reason == .fileDrag, visible.contains(.shelf) { return .shelf }
        if let module = liveActivity?.module, visible.contains(module) { return module }
        if let module = NotchModule(rawValue: settings.defaultModule), visible.contains(module) { return module }
        return currentModule
    }

    private func schedule(_ target: NotchState, after delay: Double) {
        // Already counting down toward this state; don't restart the clock on every move.
        guard pendingTarget != target else { return }
        cancelPendingTransition()
        guard delay > 0 else {
            transition(to: target)
            return
        }
        pendingTarget = target
        pendingTransition = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            pendingTarget = nil
            transition(to: target)
        }
    }

    private func transition(to target: NotchState) {
        if target == .open { open(.pointer) } else { setState(.closed) }
    }

    private func cancelPendingTransition() {
        pendingTransition?.cancel()
        pendingTransition = nil
        pendingTarget = nil
    }

    private func setState(_ newState: NotchState) {
        guard newState != state else { return }
        if state == .open, preview == nil {
            // Remember what the user was looking at, so its live activity shows once closed.
            lastViewedModule = currentModule
        }
        state = newState
        if newState == .closed { isHeldOpen = false }
        Log.notch.debug("Notch \(String(describing: newState), privacy: .public)")
        if newState == .open, settings.hapticsEnabled, preview == nil {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        onStateChange?(newState)
        if newState == .open, preview == nil { onOpen?() }
    }
}
