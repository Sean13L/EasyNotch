import AppKit

/// Keeps exactly one notch window per notched display, adding and removing them as
/// displays are connected, rearranged, or the Mac wakes from sleep.
final class ScreenManager {
    /// Called when the gear button in any notch is pressed.
    var onShowSettings: (() -> Void)?

    private let settings: AppSettings
    private let mouseTracker: MouseTracker
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var observers: [NSObjectProtocol] = []
    private var isPreviewing = false

    init(settings: AppSettings, mouseTracker: MouseTracker) {
        self.settings = settings
        self.mouseTracker = mouseTracker
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

    /// Holds every notch open (or lets them close again) while the Size settings are showing.
    func setPreview(_ isPreviewing: Bool) {
        self.isPreviewing = isPreviewing
        controllers.values.forEach { $0.viewModel.setPinnedOpen(isPreviewing) }
    }

    private func syncScreens() {
        var current = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens where screen.notchMetrics != nil {
            guard let id = screen.displayID else { continue }
            current.insert(id)
            if let controller = controllers[id] {
                controller.update(screen: screen)
            } else if let controller = NotchWindowController(screen: screen, settings: settings) {
                controller.viewModel.onShowSettings = { [weak self] in self?.onShowSettings?() }
                controller.viewModel.setPinnedOpen(isPreviewing)
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
