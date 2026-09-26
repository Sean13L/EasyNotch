import Testing
@testable import EasyNotch

struct FileDragDetectorTests {
    @Test func aDragSessionCarryingFilesIsSpotted() {
        var detector = FileDragDetector()
        detector.mouseDown(changeCount: 5)

        // The first few pixels of movement, before the drag session starts.
        let beforeSession = detector.mouseDragged(changeCount: { 5 }, hasFiles: { true })
        #expect(!beforeSession)
        // The session starts: the drag pasteboard's counter changes.
        let afterSession = detector.mouseDragged(changeCount: { 6 }, hasFiles: { true })
        #expect(afterSession)
    }

    @Test func onceDecidedItStopsAskingThePasteboard() {
        var detector = FileDragDetector()
        detector.mouseDown(changeCount: 5)
        _ = detector.mouseDragged(changeCount: { 6 }, hasFiles: { true })

        var asked = 0
        for _ in 0..<50 {
            _ = detector.mouseDragged(changeCount: { asked += 1; return 7 }, hasFiles: { asked += 1; return true })
        }
        #expect(asked == 0)
        #expect(detector.isDraggingFiles)
    }

    @Test func movingAWindowOrSelectingTextIsNotAFileDrag() {
        var detector = FileDragDetector()
        detector.mouseDown(changeCount: 5)

        var checks = 0
        for _ in 0..<100 {
            let isFileDrag = detector.mouseDragged(changeCount: { checks += 1; return 5 }, hasFiles: { true })
            #expect(!isFileDrag)
        }
        #expect(checks == FileDragDetector.maxChecks)  // gives up asking after a few events
    }

    @Test func aDragWithoutFilesIsIgnored() {
        var detector = FileDragDetector()
        detector.mouseDown(changeCount: 5)
        let isFileDrag = detector.mouseDragged(changeCount: { 6 }, hasFiles: { false })
        #expect(!isFileDrag)
    }

    @Test func releasingTheMouseEndsTheDrag() {
        var detector = FileDragDetector()
        detector.mouseDown(changeCount: 5)
        _ = detector.mouseDragged(changeCount: { 6 }, hasFiles: { true })
        detector.mouseUp()
        #expect(!detector.isDraggingFiles)
        // A drag we didn't see start (no mouse-down) is never treated as a file drag.
        let unseenDrag = detector.mouseDragged(changeCount: { 9 }, hasFiles: { true })
        #expect(!unseenDrag)
    }
}
