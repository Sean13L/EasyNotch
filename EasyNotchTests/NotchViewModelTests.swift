import CoreGraphics
import Foundation
import Testing
@testable import EasyNotch

struct NotchViewModelTests {
    // Points on the owner's screen (see NotchGeometryTests.builtIn).
    let notchCenter = CGPoint(x: 756, y: 970)
    let insideOpenPanel = CGPoint(x: 500, y: 850)      // in the open rect, far from the notch
    let desktop = CGPoint(x: 756, y: 400)              // below everything
    let menuBarLeft = CGPoint(x: 200, y: 970)          // outside the open rect
    let leftWing = CGPoint(x: 610, y: 970)             // beside the notch, inside the compact wings

    /// A view model with instant transitions and haptics off.
    func makeViewModel(_ defaults: UserDefaults, hoverDelay: Double = 0, openOnDrag: Bool = true) -> NotchViewModel {
        let settings = AppSettings(defaults: defaults)
        settings.hoverDelay = hoverDelay
        settings.shelfOpenOnDrag = openOnDrag
        settings.closeDelay = 0
        settings.hapticsEnabled = false
        let geometry = NotchGeometryTests.geometry()!
        return NotchViewModel(geometry: geometry, settings: settings)
    }

    @Test func startsClosed() {
        withIsolatedDefaults { defaults in
            #expect(makeViewModel(defaults).state == .closed)
        }
    }

    @Test func hoveringTheNotchOpensIt() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            var reported: [NotchState] = []
            vm.onStateChange = { reported.append($0) }

            vm.pointerMoved(to: notchCenter)
            #expect(vm.state == .open)
            #expect(reported == [.open])
        }
    }

    @Test func movingElsewhereWhileClosedDoesNothing() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: menuBarLeft)
            vm.pointerMoved(to: desktop)
            #expect(vm.state == .closed)
        }
    }

    @Test func staysOpenAnywhereInsideThePanel() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: notchCenter)
            vm.pointerMoved(to: insideOpenPanel)
            #expect(vm.state == .open)
        }
    }

    @Test func leavingThePanelClosesIt() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: notchCenter)
            vm.pointerMoved(to: desktop)
            #expect(vm.state == .closed)
        }
    }

    @Test func clickingOutsideClosesButClickingInsideDoesNot() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: notchCenter)

            vm.mouseDown(at: insideOpenPanel)
            #expect(vm.state == .open)

            vm.mouseDown(at: menuBarLeft)
            #expect(vm.state == .closed)
        }
    }

    @Test func expandedPreviewStaysOpenAndIgnoresThePointerUntilItEnds() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.setPreview(.expanded)
            #expect(vm.state == .open)

            vm.pointerMoved(to: desktop)
            vm.mouseDown(at: menuBarLeft)
            vm.close()
            #expect(vm.state == .open)

            vm.setPreview(nil)
            #expect(vm.state == .closed)
        }
    }

    @Test func compactPreviewShowsWingsEvenWithNothingGoingOn() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.setPreview(.compact)
            #expect(vm.presentation == .compact(.placeholder))

            vm.liveActivityProvider = { .music }
            #expect(vm.presentation == .compact(.music))  // a real activity is shown if there is one

            vm.pointerMoved(to: notchCenter)
            #expect(vm.presentation == .compact(.music))  // hovering doesn't open it mid-preview
        }
    }

    @Test func switchingFromTheExpandedToTheCompactPreviewClosesTheNotch() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.setPreview(.expanded)
            vm.setPreview(.compact)
            #expect(vm.state == .closed)
            #expect(vm.presentation == .compact(.placeholder))
        }
    }

    @Test func endingAPreviewThatWasNeverStartedLeavesAHoverOpenedNotchAlone() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: notchCenter)
            vm.setPreview(nil)
            #expect(vm.state == .open)
        }
    }

    @Test func presentationFollowsStateAndLiveActivity() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            #expect(vm.presentation == .closed)

            vm.liveActivityProvider = { .pomodoro }
            #expect(vm.presentation == .compact(.pomodoro))

            vm.pointerMoved(to: notchCenter)
            #expect(vm.presentation == .open)
        }
    }

    @Test func hoveringAWingOpensOnlyWhileAnActivityShows() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerMoved(to: leftWing)
            #expect(vm.state == .closed)

            vm.liveActivityProvider = { .pomodoro }
            vm.pointerMoved(to: leftWing)
            #expect(vm.state == .open)
        }
    }

    @Test func openingFromALiveActivityShowsItsTab() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.selectedModule = .music
            vm.liveActivityProvider = { .pomodoro }
            vm.pointerMoved(to: notchCenter)
            #expect(vm.selectedModule == .pomodoro)
        }
    }

    // MARK: - Dragging files

    @Test func draggingFilesNearTheNotchOpensTheShelfInstantly() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults, hoverDelay: 1)  // no waiting, even with a delay set
            vm.selectedModule = .music
            vm.pointerDragged(to: notchCenter, carryingFiles: true)
            #expect(vm.state == .open)
            #expect(vm.selectedModule == .shelf)
        }
    }

    @Test func otherDragsNeverOpenTheNotch() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerDragged(to: notchCenter, carryingFiles: false)  // e.g. moving a window
            #expect(vm.state == .closed)
        }
    }

    @Test func dragOpeningCanBeTurnedOff() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults, openOnDrag: false)
            vm.pointerDragged(to: notchCenter, carryingFiles: true)
            #expect(vm.state == .closed)
        }
    }

    @Test func filesDraggedElsewhereDoNotOpenTheNotch() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerDragged(to: desktop, carryingFiles: true)
            #expect(vm.state == .closed)
        }
    }

    @Test func draggingAwayFromTheOpenNotchClosesIt() {
        withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults)
            vm.pointerDragged(to: notchCenter, carryingFiles: true)
            vm.pointerDragged(to: desktop, carryingFiles: true)
            #expect(vm.state == .closed)
        }
    }

    @Test func hoverDelayIsRespected() async {
        await withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults, hoverDelay: 0.05)
            vm.pointerMoved(to: notchCenter)
            #expect(vm.state == .closed)  // not yet

            try? await Task.sleep(for: .milliseconds(300))
            #expect(vm.state == .open)
        }
    }

    @Test func leavingBeforeTheHoverDelayCancelsOpening() async {
        await withIsolatedDefaults { defaults in
            let vm = makeViewModel(defaults, hoverDelay: 0.1)
            vm.pointerMoved(to: notchCenter)
            vm.pointerMoved(to: desktop)

            try? await Task.sleep(for: .milliseconds(300))
            #expect(vm.state == .closed)
        }
    }
}
