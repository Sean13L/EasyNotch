import AppKit
import SwiftUI

/// The feature services the notch's views use, handed to SwiftUI through the environment.
struct NotchFeatures {
    let pomodoro: PomodoroController
    let nowPlaying: NowPlayingService
}

/// Owns the notch window for one screen and keeps it in sync with the view model and the
/// size settings.
final class NotchWindowController {
    let displayID: CGDirectDisplayID
    let viewModel: NotchViewModel

    private let panel: NotchPanel
    private let settings: AppSettings
    private var metrics: ScreenMetrics

    /// Returns nil for a screen without a notch.
    init?(screen: NSScreen, settings: AppSettings, features: NotchFeatures) {
        guard let displayID = screen.displayID,
              let metrics = screen.notchMetrics,
              let geometry = Self.geometry(for: metrics, settings: settings)
        else { return nil }

        self.displayID = displayID
        self.metrics = metrics
        self.settings = settings
        viewModel = NotchViewModel(geometry: geometry, settings: settings)
        panel = NotchPanel(frame: geometry.panelFrame)

        let rootView = NotchRootView(viewModel: viewModel)
            .environment(features.pomodoro)
            .environment(features.nowPlaying)
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

    /// The screen moved, resized, or changed resolution.
    func update(screen: NSScreen) {
        guard let newMetrics = screen.notchMetrics, newMetrics != metrics else { return }
        metrics = newMetrics
        relayout()
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
