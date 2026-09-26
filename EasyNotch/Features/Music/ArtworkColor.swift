import AppKit

/// Picks the color that stands out in a cover, for the audio bars beside the notch.
///
/// Averaging every pixel tends to give a muddy brown-grey, so instead this finds the most
/// prominent *vivid* hue: pixels are grouped by hue, and bright, saturated pixels count most.
/// The result is brightened if needed, so the bars stay visible on the black notch.
nonisolated enum ArtworkColor {
    /// The cover is shrunk to this many pixels on each side before looking at it.
    static let sampleSize = 24
    /// Hue groups around the color wheel (15° each).
    static let hueGroups = 24
    /// A hue needs at least this share of the cover to count; otherwise it's black-and-white.
    static let minimumShare = 0.03
    /// Darker colors are raised to this brightness.
    static let minimumBrightness = 0.85
    /// What a cover without any real color gets: a light grey that matches it.
    static let colorless = NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)

    static func color(of image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return color(ofPixels: pixels(of: cgImage))
    }

    /// The image shrunk to `sampleSize`², as sRGB bytes: red, green, blue, alpha, … (with the
    /// color already multiplied by alpha, which is how Core Graphics stores it).
    static func pixels(of image: CGImage) -> [UInt8] {
        let size = sampleSize
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return bytes
    }

    /// The standout color of pixels laid out as in `pixels(of:)`.
    static func color(ofPixels rgba: [UInt8]) -> NSColor? {
        var weight = [Double](repeating: 0, count: hueGroups)
        var count = [Int](repeating: 0, count: hueGroups)
        var red = [Double](repeating: 0, count: hueGroups)
        var green = [Double](repeating: 0, count: hueGroups)
        var blue = [Double](repeating: 0, count: hueGroups)
        var opaquePixels = 0

        for start in stride(from: 0, to: rgba.count - 3, by: 4) {
            let alpha = Double(rgba[start + 3]) / 255
            guard alpha >= 0.5 else { continue }  // see-through pixels aren't part of the cover
            opaquePixels += 1
            let r = Double(rgba[start]) / 255 / alpha
            let g = Double(rgba[start + 1]) / 255 / alpha
            let b = Double(rgba[start + 2]) / 255 / alpha
            let (hue, saturation, brightness) = hsb(r, g, b)
            // Greys, near-blacks, and washed-out pixels say nothing about the cover's color.
            guard saturation >= 0.25, brightness >= 0.2 else { continue }

            let group = min(Int(hue * Double(hueGroups)), hueGroups - 1)
            let vividness = saturation * brightness
            weight[group] += vividness
            count[group] += 1
            red[group] += r * vividness
            green[group] += g * vividness
            blue[group] += b * vividness
        }
        guard opaquePixels > 0 else { return nil }

        // Look at each group with its two neighbours, so a hue on a boundary (red sits at both
        // 0° and 360°) isn't split in half.
        func around(_ group: Int) -> [Int] {
            [(group + hueGroups - 1) % hueGroups, group, (group + 1) % hueGroups]
        }
        let best = (0..<hueGroups).max { a, b in
            around(a).map { weight[$0] }.reduce(0, +) < around(b).map { weight[$0] }.reduce(0, +)
        }!
        let groups = around(best)
        let bestCount = groups.map { count[$0] }.reduce(0, +)
        guard Double(bestCount) >= minimumShare * Double(opaquePixels) else { return colorless }

        let total = groups.map { weight[$0] }.reduce(0, +)
        return readable(
            red: groups.map { red[$0] }.reduce(0, +) / total,
            green: groups.map { green[$0] }.reduce(0, +) / total,
            blue: groups.map { blue[$0] }.reduce(0, +) / total
        )
    }

    /// The same hue, brightened if it would be too dark to see on black.
    static func readable(red: Double, green: Double, blue: Double) -> NSColor {
        let (hue, saturation, brightness) = hsb(red, green, blue)
        return NSColor(
            hue: hue, saturation: saturation, brightness: max(brightness, minimumBrightness), alpha: 1
        ).usingColorSpace(.sRGB)!
    }

    /// Hue, saturation, and brightness, each 0…1.
    static func hsb(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maximum = max(r, g, b)
        let range = maximum - min(r, g, b)
        guard maximum > 0, range > 0 else { return (0, 0, maximum) }
        var hue: Double
        switch maximum {
        case r: hue = (g - b) / range
        case g: hue = (b - r) / range + 2
        default: hue = (r - g) / range + 4
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, range / maximum, maximum)
    }
}
