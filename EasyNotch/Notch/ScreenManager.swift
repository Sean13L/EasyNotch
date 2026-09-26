import AppKit

/// Keeps exactly one notch window per notched display, adding and removing them as
/// displays are connected, rearranged, or the Mac wakes from sleep.
final class ScreenManager {
    /// Called when the gear button in any notch is pressed.
    var onShowSettings: (() -> Void)?
    /// Decides what shows beside the closed notch; passed on to every screen's notch.
    var liveActivityProvider: () -> LiveActivity? = { nil }

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
        mouseTracker.start()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncScreens() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncScreens() }
        })

        syncScreens()
    }

    /// Holds every notch in the previewed shape while the Size settings are showing, or lets
    /// them behave normally again (`nil`).
    func setPreview(_ preview: SizePreview?) {
        self.preview = preview
        controllers.values.forEach { $0.viewModel.setPreview(preview) }
    }

    private func syncScreens() {
        var current = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens where screen.notchMetrics != nil {
            guard let id = screen.displayID else { continue }
            current.insert(id)
            if let controller = controllers[id] {
                controller.update(screen: screen)
            } else if let controller = NotchWindowController(screen: screen, settings: settings, features: features) {
                controller.viewModel.onShowSettings = { [weak self] in self?.onShowSettings?() }
                controller.viewModel.liveActivityProvider = liveActivityProvider
                controller.viewModel.setPreview(preview)
                controllers[id] = controller
            }
        }
        for (id, controller) in controllers where !current.contains(id) {
            controller.close()
            controllers[id] = nil
        }
        Log.notch.notice("Notch windows: \(self.controllers.count)")
    }
}
