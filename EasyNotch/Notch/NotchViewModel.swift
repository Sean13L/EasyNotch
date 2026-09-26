import AppKit
import Observation

enum NotchState: Equatable {
    case closed
    case open
}

/// The state of one screen's notch. It turns pointer positions into open/closed decisions,
/// waiting for the hover and close delays from `AppSettings` before switching.
@Observable
final class NotchViewModel {
    private(set) var state: NotchState = .closed
    private(set) var geometry: NotchGeometry
    var selectedModule: NotchModule = .music
    /// Set while the Size settings pane is showing, so you can watch the notch change as you
    /// drag its sliders. The pointer is ignored during a preview.
    private(set) var preview: SizePreview?

    /// Which live activity (if any) should show beside the closed notch. Set by `AppServices`,
    /// so the notch never needs to know about individual features.
    @ObservationIgnored var liveActivityProvider: () -> LiveActivity? = { nil }
    /// Called after every state change; the window controller uses it to toggle click-through.
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
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

    var liveActivity: LiveActivity? { liveActivityProvider() }

    var presentation: NotchPresentation {
        if state == .open { return .open }
        if preview == .compact {
            // Show the wings even when nothing is playing, so their width can be judged.
            return .compact(liveActivity ?? .placeholder)
        }
        if let liveActivity { return .compact(liveActivity) }
        return .closed
    }

    func pointerMoved(to point: CGPoint) {
        guard preview == nil else { return }
        switch state {
        case .closed:
            // Mouse moves arrive constantly; skip the rest unless the pointer is near the notch.
            // (The compact hot zone always contains the plain one.)
            guard geometry.compactHotZone.contains(point) else {
                cancelPendingTransition()
                return
            }
            let hotZone = liveActivity == nil ? geometry.hotZone : geometry.compactHotZone
            if hotZone.contains(point) {
                schedule(.open, after: settings.hoverDelay)
            } else {
                cancelPendingTransition()
            }
        case .open:
            if geometry.openRect.contains(point) {
                cancelPendingTransition()
            } else {
                schedule(.closed, after: settings.closeDelay)
            }
        }
    }

    /// A click anywhere outside the open notch closes it right away.
    func mouseDown(at point: CGPoint) {
        guard state == .open, preview == nil, !geometry.openRect.contains(point) else { return }
        close()
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

    private func schedule(_ target: NotchState, after delay: Double) {
        // Already counting down toward this state; don't restart the clock on every move.
        guard pendingTarget != target else { return }
        cancelPendingTransition()
        guard delay > 0 else {
            setState(target)
            return
        }
        pendingTarget = target
        pendingTransition = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            pendingTarget = nil
            setState(target)
        }
    }

    private func cancelPendingTransition() {
        pendingTransition?.cancel()
        pendingTransition = nil
        pendingTarget = nil
    }

    private func setState(_ newState: NotchState) {
        guard newState != state else { return }
        state = newState
        // Opening from a live activity shows that activity's tab, like tapping the Dynamic Island.
        if newState == .open, preview == nil, let module = liveActivity?.module {
            selectedModule = module
        }
        Log.notch.debug("Notch \(String(describing: newState), privacy: .public)")
        if newState == .open, settings.hapticsEnabled, preview == nil {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        onStateChange?(newState)
    }
}
