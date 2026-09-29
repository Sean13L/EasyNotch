import AppKit

/// Keeps one notch window per chosen display (Settings → Displays), adding and removing them as
/// displays are connected, rearranged, or the Mac wakes from sleep. Screens without a notch get
/// a virtual one. It also hides notches over full-screen apps when that option is on.
final class ScreenManager {
    /// Called when Settings should open (the gear button or the right-click menu).
    var onShowSettings: (() -> Void)?
    /// Decides what shows beside the closed notch; passed on to every screen's notch.
    var liveActivityProvider: (NotchModule?) -> LiveActivity? = { _ in nil }
    /// Called when any notch opens.
    var onNotchOpened: (() -> Void)?

    private let settings: AppSettings
    private let mouseTracker: MouseTracker
    private let features: NotchFeatures
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var observers: [NSObjectProtocol] = []
    private var preview: SizePreview?

    init(settings: AppSettings, mouseTracker: MouseTracker, features: NotchFeatures) {
        self.settings = settings
        self.mouseTracker = mouseTracker
        self.features = features
    }

    func start() {
        mouseTracker.onMove = { [weak self] point in
            self?.controllers.values.forEach { $0.viewModel.pointerMoved(to: point) }
        }
        mouseTracker.onMouseDown = { [weak self] point in
            self?.controllers.values.forEach { $0.viewModel.mouseDown(at: point) }
        }
        mouseTracker.onRightMouseDown = { [weak self] point in
            self?.rightMouseDown(at: point)
        }
        mouseTracker.onDrag = { [weak self] point, carryingFiles in
            self?.controllers.values.forEach { $0.viewModel.pointerDragged(to: point, carryingFiles: carryingFiles) }
        }
        mouseTracker.start()

        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.syncScreens() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification) { $0.syncScreens() }
        // Entering or leaving full screen switches Spaces; switching apps can too.
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.updateFullScreenHiding() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.updateFullScreenHiding() }

        syncScreens()
        watchDisplaySettings()
    }

    /// Holds every notch in the previewed shape while the Size settings are showing, or lets
    /// them behave normally again (`nil`).
    func setPreview(_ preview: SizePreview?) {
        self.preview = preview
        controllers.values.forEach { $0.viewModel.setPreview(preview) }
    }

    /// The keyboard shortcut: toggles the notch on the screen with the pointer.
    func toggleFromShortcut() {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.values.first { $0.viewModel.geometry.screenFrame.contains(pointer) }
            ?? controllers.values.first
        controller?.viewModel.toggleFromShortcut()
    }

    // MARK: - Private

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping @MainActor (ScreenManager) -> Void
    ) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        })
    }

    private func rightMouseDown(at point: CGPoint) {
        var isOnNotch = false
        for controller in controllers.values where controller.viewModel.rightMouseDown(at: point) {
            isOnNotch = true
        }
        if isOnNotch {
            NotchContextMenu.show(at: point) { [weak self] in self?.onShowSettings?() }
        }
    }

    /// The screens that should have a notch, with the notch measurements for each.
    private func chosenScreens() -> [(id: CGDirectDisplayID, metrics: ScreenMetrics)] {
        let screens = NSScreen.screens
        let chosen: [NSScreen] = switch settings.displayMode {
        case "all": screens
        case "main": Array(screens.prefix(1))  // the screen with the menu bar and Dock
        default: screens.filter(\.isBuiltIn)
        }
        return chosen.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            let metrics = screen.notchMetrics ?? screen.virtualNotchMetrics(width: settings.virtualNotchWidth)
            return (id, metrics)
        }
    }

    private func syncScreens() {
        let chosen = chosenScreens()
        for (id, metrics) in chosen {
            if let controller = controllers[id] {
                controller.update(metrics: metrics)
            } else if let controller = NotchWindowController(
                displayID: id, metrics: metrics, settings: settings, features: features
            ) {
                controller.viewModel.onShowSettings = { [weak self] in self?.onShowSettings?() }
                controller.viewModel.liveActivityProvider = liveActivityProvider
                controller.viewModel.onOpen = { [weak self] in self?.onNotchOpened?() }
                controller.viewModel.setPreview(preview)
                controllers[id] = controller
            }
        }
        let chosenIDs = Set(chosen.map(\.id))
        for (id, controller) in controllers where !chosenIDs.contains(id) {
            controller.close()
            controllers[id] = nil
        }
        Log.notch.notice("Notch windows: \(self.controllers.count)")
        updateFullScreenHiding()
    }

    private func updateFullScreenHiding() {
        let hide = settings.hideInFullScreen
        for (id, controller) in controllers {
            controller.setHiddenForFullScreen(hide && FullScreenDetector.isFullScreen(displayID: id))
        }
        // Space-switch animations take a moment; check again once they've finished.
        guard hide else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, settings.hideInFullScreen else { return }
            for (id, controller) in controllers {
                controller.setHiddenForFullScreen(FullScreenDetector.isFullScreen(displayID: id))
            }
        }
    }

    /// Rebuilds the notch windows when the display options change.
    private func watchDisplaySettings() {
        withObservationTracking {
            _ = settings.displayMode
            _ = settings.virtualNotchWidth
            _ = settings.hideInFullScreen
        } onChange: { [weak self] in
            // onChange fires just before the new value is stored; look on the next main-loop turn.
            Task { @MainActor [weak self] in
                self?.syncScreens()
                self?.watchDisplaySettings()
            }
        }
    }
}
