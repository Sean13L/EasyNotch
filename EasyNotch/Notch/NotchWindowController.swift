import AppKit
import SwiftUI

/// The feature services the notch's views use, handed to SwiftUI through the environment.
struct NotchFeatures {
    let pomodoro: PomodoroController
    let nowPlaying: NowPlayingService
    let shelf: ShelfStore
}

/// Owns the notch window for one screen and keeps it in sync with the view model and the
/// size settings.
final class NotchWindowController {
    let displayID: CGDirectDisplayID
    let viewModel: NotchViewModel

    private let panel: NotchPanel
    private let settings: AppSettings
    private var metrics: ScreenMetrics
    private var isHiddenForFullScreen = false

    /// `metrics` describes the screen's notch: its real one, or a virtual one drawn on a screen
    /// without a notch. Returns nil if the measurements don't make sense.
    init?(displayID: CGDirectDisplayID, metrics: ScreenMetrics, settings: AppSettings, features: NotchFeatures) {
        guard let geometry = Self.geometry(for: metrics, settings: settings) else { return nil }

        self.displayID = displayID
        self.metrics = metrics
        self.settings = settings
        viewModel = NotchViewModel(geometry: geometry, settings: settings)
        panel = NotchPanel(frame: geometry.panelFrame)

        let rootView = NotchRootView(viewModel: viewModel)
            .environment(features.pomodoro)
            .environment(features.nowPlaying)
            .environment(features.shelf)
        let hostingView = NotchHostingView(rootView: rootView)
        // Without this, SwiftUI would resize the window to fit its content; we size it ourselves.
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        viewModel.onStateChange = { [weak self] state in
            self?.panel.ignoresMouseEvents = (state == .closed)
        }
        panel.orderFrontRegardless()
        observeSizeSettings()
    }

    /// The screen moved, resized, or changed resolution (or the virtual notch's width changed).
    func update(metrics newMetrics: ScreenMetrics) {
        guard newMetrics != metrics else { return }
        metrics = newMetrics
        relayout()
    }

    /// Hides the notch while an app on this screen is full screen (if that option is on).
    func setHiddenForFullScreen(_ hidden: Bool) {
        guard hidden != isHiddenForFullScreen else { return }
        isHiddenForFullScreen = hidden
        if hidden {
            viewModel.close()
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
        Log.notch.debug("\(hidden ? "Notch hidden: an app is full screen" : "Notch shown again: full screen ended", privacy: .public)")
    }

    func close() {
        viewModel.close()
        panel.orderOut(nil)
        panel.close()
    }

    // MARK: - Private

    private func relayout() {
        guard let geometry = Self.geometry(for: metrics, settings: settings) else { return }
        viewModel.update(geometry: geometry)
        panel.setFrame(geometry.panelFrame, display: true)
    }

    /// Re-frames the window whenever a size-related setting changes.
    private func observeSizeSettings() {
        withObservationTracking {
            _ = settings.expandedWidth
            _ = settings.expandedHeight
            _ = settings.compactWingWidth
            _ = settings.hotZoneMargin
        } onChange: { [weak self] in
            // onChange fires just *before* the new value is stored, and only once, so re-read
            // on the next turn of the main loop and then start watching again.
            Task { @MainActor [weak self] in
                self?.relayout()
                self?.observeSizeSettings()
            }
        }
    }

    private static func geometry(for metrics: ScreenMetrics, settings: AppSettings) -> NotchGeometry? {
        NotchGeometry(
            metrics: metrics,
            openSize: CGSize(width: settings.expandedWidth, height: settings.expandedHeight),
            compactWingWidth: settings.compactWingWidth,
            hotZoneMargin: settings.hotZoneMargin
        )
    }
}
