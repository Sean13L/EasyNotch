import AppKit
import Testing
@testable import EasyNotch

struct ArtworkColorTests {
    typealias RGB = (r: UInt8, g: UInt8, b: UInt8)

    /// A made-up cover: each color fills its share of the pixels (the shares add up to 1).
    func cover(_ parts: [(RGB, Double)], alpha: UInt8 = 255) -> [UInt8] {
        let total = ArtworkColor.sampleSize * ArtworkColor.sampleSize
        var pixels: [UInt8] = []
        for (color, share) in parts {
            for _ in 0..<Int((share * Double(total)).rounded()) {
                pixels += [color.r, color.g, color.b, alpha]
            }
        }
        return pixels
    }

    func hsb(_ color: NSColor?) throws -> (hue: Double, saturation: Double, brightness: Double) {
        let color = try #require(color?.usingColorSpace(.sRGB))
        return (color.hueComponent, color.saturationComponent, color.brightnessComponent)
    }

    @Test func aBlueCoverGivesBlue() throws {
        let color = try hsb(ArtworkColor.color(ofPixels: cover([((30, 90, 230), 1)])))
        #expect(abs(color.hue - 0.63) < 0.02)
        #expect(color.saturation > 0.8)
    }

    @Test func theVividColorWinsOverALargerGreyArea() throws {
        // 60% grey background, 40% orange: the bars should be orange, not grey.
        let color = try hsb(ArtworkColor.color(ofPixels: cover([((128, 128, 128), 0.6), ((245, 140, 20), 0.4)])))
        #expect(abs(color.hue - 0.09) < 0.02)
    }

    @Test func aSmallLogoOnBlackStillCounts() throws {
        // A black cover with a red logo covering 5% of it.
        let color = try hsb(ArtworkColor.color(ofPixels: cover([((0, 0, 0), 0.95), ((220, 20, 30), 0.05)])))
        #expect(color.hue < 0.02 || color.hue > 0.98)
    }

    @Test func redIsNotSplitAcrossTheEndsOfTheColorWheel() throws {
        // Two reds just either side of 0°/360°, against a smaller patch of green.
        let color = try hsb(ArtworkColor.color(ofPixels: cover([
            ((230, 20, 40), 0.3), ((230, 40, 20), 0.3), ((40, 200, 60), 0.4),
        ])))
        #expect(color.hue < 0.03 || color.hue > 0.97)
    }

    @Test func aBlackAndWhiteCoverGivesLightGrey() {
        let color = ArtworkColor.color(ofPixels: cover([((10, 10, 10), 0.7), ((240, 240, 240), 0.3)]))
        #expect(color == ArtworkColor.colorless)
    }

    @Test func darkCoversAreBrightenedToStayVisible() throws {
        // Navy would disappear against the black notch.
        let color = try hsb(ArtworkColor.color(ofPixels: cover([((20, 30, 90), 1)])))
        #expect(color.brightness >= ArtworkColor.minimumBrightness - 0.001)
        #expect(abs(color.hue - 0.64) < 0.02)  // still navy's hue
    }

    @Test func seeThroughPixelsAreIgnored() {
        #expect(ArtworkColor.color(ofPixels: cover([((255, 0, 0), 1)], alpha: 20)) == nil)
    }

    @Test func aRealImageGoesThroughTheWholeProcess() throws {
        // A 300×300 image, green on the left two-thirds and white on the right.
        let image = NSImage(size: NSSize(width: 300, height: 300), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSColor(srgbRed: 0.1, green: 0.7, blue: 0.3, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 200, height: 300).fill()
            return true
        }
        let color = try hsb(ArtworkColor.color(of: image))
        #expect(abs(color.hue - 0.38) < 0.03)
    }
}
