// Draws EasyNotch's app icon: a 1024×1024 PNG.
//
//   swift scripts/make-icon.swift /path/to/icon-1024.png
//
// scripts/make-icon.sh then turns it into every size the app needs.
// Design: a macOS-style rounded square with an indigo-to-cyan gradient, and a black notch
// hanging from the top edge showing its "wings" (a timer ring and equalizer bars).

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

guard let context = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Couldn't create a drawing context") }

// CoreGraphics measures from the bottom-left; flip so y grows downward like a page.
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// MARK: Rounded square (Apple's icon grid: 824 pt body, 100 pt margin)

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Soft shadow under the whole icon.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0x000000, 0.35))
context.addPath(bodyPath)
context.setFillColor(color(0x1E1B4B))
context.fillPath()
context.restoreGState()

// Gradient fill, clipped to the rounded square.
context.saveGState()
context.addPath(bodyPath)
context.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [color(0x4F46E5), color(0x7C3AED), color(0x06B6D4)] as CFArray,
    locations: [0, 0.5, 1]
)!
context.drawLinearGradient(
    gradient, start: CGPoint(x: body.minX, y: body.minY), end: CGPoint(x: body.maxX, y: body.maxY), options: []
)
// A gentle light from the top, like a screen's glow.
let glow = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
    endCenter: CGPoint(x: 512, y: 560), endRadius: 520, options: []
)

// MARK: The notch with its wings, hanging from the top edge

let notchWidth: CGFloat = 200     // the "hardware" part in the middle
let wing: CGFloat = 215           // each wing
let height: CGFloat = 300
let ear: CGFloat = 44             // concave curve where it meets the top edge
let corner: CGFloat = 96
let left = 512 - notchWidth / 2 - wing
let right = 512 + notchWidth / 2 + wing
let top = body.minY
let bottom = top + height

let notch = CGMutablePath()
notch.move(to: CGPoint(x: left - ear, y: top))
notch.addQuadCurve(to: CGPoint(x: left, y: top + ear), control: CGPoint(x: left, y: top))
notch.addLine(to: CGPoint(x: left, y: bottom - corner))
notch.addQuadCurve(to: CGPoint(x: left + corner, y: bottom), control: CGPoint(x: left, y: bottom))
notch.addLine(to: CGPoint(x: right - corner, y: bottom))
notch.addQuadCurve(to: CGPoint(x: right, y: bottom - corner), control: CGPoint(x: right, y: bottom))
notch.addLine(to: CGPoint(x: right, y: top + ear))
notch.addQuadCurve(to: CGPoint(x: right + ear, y: top), control: CGPoint(x: right, y: top))
notch.closeSubpath()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: color(0x000000, 0.45))
context.addPath(notch)
context.setFillColor(color(0x000000))
context.fillPath()
context.restoreGState()

let centerY = top + height * 0.56

// Left wing: a timer ring, about two-thirds done.
let ringCenter = CGPoint(x: left + wing / 2 + 14, y: centerY)
let ringRadius: CGFloat = 64
context.setLineWidth(26)
context.setLineCap(.round)
context.setStrokeColor(color(0xFF6B52, 0.28))
context.addArc(center: ringCenter, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.strokePath()
context.setStrokeColor(color(0xFF6B52))
context.addArc(
    center: ringCenter, radius: ringRadius,
    startAngle: -.pi / 2, endAngle: -.pi / 2 + .pi * 2 * 0.68, clockwise: false
)
context.strokePath()

// Right wing: equalizer bars.
let barHeights: [CGFloat] = [78, 150, 104, 172, 92]
let barWidth: CGFloat = 23
let barGap: CGFloat = 15
let barsWidth = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * barGap
var barX = right - wing / 2 - 14 - barsWidth / 2
context.setFillColor(color(0x34D17A))
for barHeight in barHeights {
    let bar = CGRect(x: barX, y: centerY - barHeight / 2, width: barWidth, height: barHeight)
    context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
    context.fillPath()
    barX += barWidth + barGap
}

// A tiny camera lens in the middle, so it reads as a MacBook notch.
context.setFillColor(color(0x1C1C24))
context.fillEllipse(in: CGRect(x: 512 - 22, y: top + 46, width: 44, height: 44))
context.setFillColor(color(0x3A3F66))
context.fillEllipse(in: CGRect(x: 512 - 10, y: top + 58, width: 20, height: 20))

context.restoreGState()

// MARK: Save

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil
      )
else { fatalError("Couldn't create the PNG") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(output)") }
print("Wrote \(output)")
