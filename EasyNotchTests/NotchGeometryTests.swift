import CoreGraphics
import Testing
@testable import EasyNotch

struct NotchGeometryTests {
    /// The owner's MacBook, measured 2026-09-25: 1512×982 pt, notch 185×32 pt.
    static let builtIn = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        notchHeight: 32,
        leftAreaWidth: 663.5,
        rightAreaWidth: 663.5
    )

    static func geometry(
        _ metrics: ScreenMetrics = builtIn,
        open: CGSize = CGSize(width: 640, height: 200),
        wings: CGFloat = 64,
        margin: CGFloat = 8
    ) -> NotchGeometry? {
        NotchGeometry(metrics: metrics, openSize: open, compactWingWidth: wings, hotZoneMargin: margin)
    }

    @Test func notchMatchesRealHardware() throws {
        let g = try #require(Self.geometry())
        #expect(g.notchRect == CGRect(x: 663.5, y: 950, width: 185, height: 32))
    }

    @Test func openRectIsCenteredUnderNotchAndTouchesTop() throws {
        let g = try #require(Self.geometry())
        #expect(g.openRect == CGRect(x: 436, y: 782, width: 640, height: 200))
        #expect(g.openRect.midX == g.notchRect.midX)
        #expect(g.openRect.maxY == 982)
    }

    @Test func panelLeavesRoomForShadow() throws {
        let g = try #require(Self.geometry())
        #expect(g.panelFrame == CGRect(x: 412, y: 758, width: 688, height: 224))
    }

    @Test func hotZoneCoversNotchPlusMargin() throws {
        let g = try #require(Self.geometry())
        #expect(g.hotZone.contains(CGPoint(x: 756, y: 981)))   // top edge, center
        #expect(g.hotZone.contains(CGPoint(x: 658, y: 944)))   // just outside the notch corner
        #expect(!g.hotZone.contains(CGPoint(x: 600, y: 970)))  // menu-bar items to the left
        #expect(!g.hotZone.contains(CGPoint(x: 756, y: 900)))  // well below the notch
    }

    @Test func localRectFlipsToTopLeftOrigin() throws {
        let g = try #require(Self.geometry())
        #expect(g.localRect(g.notchRect) == CGRect(x: 251.5, y: 0, width: 185, height: 32))
        #expect(g.localRect(g.openRect) == CGRect(x: 24, y: 0, width: 640, height: 200))
    }

    @Test func compactRectAddsWingsBesideTheNotch() throws {
        let g = try #require(Self.geometry())
        #expect(g.compactRect == CGRect(x: 599.5, y: 950, width: 313, height: 32))
        #expect(g.compactHotZone.contains(CGPoint(x: 610, y: 970)))  // left wing
        #expect(!g.hotZone.contains(CGPoint(x: 610, y: 970)))        // not part of the plain notch
    }

    @Test func panelFitsWideWingsEvenWithANarrowOpenSize() throws {
        let g = try #require(Self.geometry(open: CGSize(width: 200, height: 120), wings: 120))
        #expect(g.panelFrame.contains(g.compactRect))
        #expect(g.panelFrame.contains(g.openRect))
    }

    @Test func screenWithoutNotchHasNoGeometry() {
        var metrics = Self.builtIn
        metrics.notchHeight = 0
        #expect(Self.geometry(metrics) == nil)
    }

    @Test func secondaryDisplayUsesItsOwnOrigin() throws {
        // A display placed to the right of and above the main one.
        let metrics = ScreenMetrics(
            frame: CGRect(x: 1512, y: 109, width: 1920, height: 1080),
            notchHeight: 32,
            leftAreaWidth: 867.5,
            rightAreaWidth: 867.5
        )
        let g = try #require(Self.geometry(metrics))
        #expect(g.notchRect == CGRect(x: 2379.5, y: 1157, width: 185, height: 32))
        #expect(g.openRect.maxY == 1189)
    }

    @Test func offCenterNotchIsFollowed() throws {
        var metrics = Self.builtIn
        metrics.leftAreaWidth = 600
        metrics.rightAreaWidth = 727
        let g = try #require(Self.geometry(metrics))
        #expect(g.notchRect.minX == 600)
        #expect(g.notchRect.width == 185)
        #expect(g.openRect.midX == g.notchRect.midX)
    }

    @Test func openSizeIsClampedBetweenNotchAndScreen() throws {
        let tooSmall = try #require(Self.geometry(open: CGSize(width: 50, height: 10)))
        #expect(tooSmall.openRect.size == CGSize(width: 185, height: 32))

        let tooBig = try #require(Self.geometry(open: CGSize(width: 5000, height: 5000)))
        #expect(tooBig.openRect == tooBig.screenFrame)
    }

    @Test func openRectAndPanelStayOnScreenNearAnEdge() throws {
        var metrics = Self.builtIn
        metrics.leftAreaWidth = 10  // notch hugging the left edge
        metrics.rightAreaWidth = 1317
        let g = try #require(Self.geometry(metrics))
        #expect(g.openRect.minX == 0)
        #expect(g.panelFrame.minX == 0)
        #expect(g.screenFrame.contains(g.panelFrame))
    }
}
