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
    /// While true, the notch stays open no matter where the pointer goes. The Size settings
    /// pane uses this so you can watch the notch change as you drag the sliders.
    private(set) var isPinnedOpen = false

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

    func pointerMoved(to point: CGPoint) {
        guard !isPinnedOpen else { return }
        switch state {
        case .closed:
            if geometry.hotZone.contains(point) {
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
        guard state == .open, !isPinnedOpen, !geometry.openRect.contains(point) else { return }
        close()
    }

    func close() {
        guard !isPinnedOpen else { return }
        cancelPendingTransition()
        setState(.closed)
    }

    func setPinnedOpen(_ pinned: Bool) {
        guard pinned != isPinnedOpen else { return }
        isPinnedOpen = pinned
        cancelPendingTransition()
        setState(pinned ? .open : .closed)
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
        Log.notch.debug("Notch \(String(describing: newState), privacy: .public)")
        if newState == .open, settings.hapticsEnabled, !isPinnedOpen {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        onStateChange?(newState)
    }
}
