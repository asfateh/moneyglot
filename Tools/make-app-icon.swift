// Renders the Moneyglot app icon (1024×1024, no alpha channel, as App Store Connect requires).
// Usage: swift Tools/make-app-icon.swift Moneyglot/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let s = CGFloat(size)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
}

// Background: indigo → teal diagonal.
context.drawLinearGradient(
    gradient([color(0x3A2D9E), color(0x0E9F8E)]),
    start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: []
)

// Faint globe lines: "every currency in the world".
let center = CGPoint(x: s / 2, y: s / 2)
let radius: CGFloat = 410
context.setStrokeColor(color(0xFFFFFF, 0.10))
context.setLineWidth(10)
context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
for factor in [0.38, 0.75] as [CGFloat] {
    let w = radius * factor
    context.strokeEllipse(in: CGRect(x: center.x - w, y: center.y - radius, width: w * 2, height: radius * 2))
}
for offset in [-0.5, 0, 0.5] as [CGFloat] {
    let y = center.y + radius * offset
    let half = sqrt(radius * radius - (radius * offset) * (radius * offset))
    context.move(to: CGPoint(x: center.x - half, y: y))
    context.addLine(to: CGPoint(x: center.x + half, y: y))
}
context.strokePath()

/// Rounded speech bubble with a tail on the bottom-left or bottom-right, filled as one opaque shape.
func fillBubble(_ rect: CGRect, radius: CGFloat, tailOnLeft: Bool, color fill: CGColor) {
    let x = tailOnLeft ? rect.minX + radius : rect.maxX - radius
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: x - 50, y: rect.minY + 40))
    tail.addLine(to: CGPoint(x: tailOnLeft ? x - 85 : x + 85, y: rect.minY - 95))
    tail.addLine(to: CGPoint(x: x + 50, y: rect.minY + 40))
    tail.closeSubpath()
    context.setFillColor(fill)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
    context.addPath(tail)
    context.fillPath()
}

// Back bubble (mint, translucent) — the "other language / other currency".
context.saveGState()
context.setAlpha(0.55)
context.beginTransparencyLayer(auxiliaryInfo: nil)
fillBubble(CGRect(x: 395, y: 470, width: 450, height: 330), radius: 105, tailOnLeft: false, color: color(0x8FF5E1))
context.endTransparencyLayer()
context.restoreGState()

// Front bubble (white) with a rising bar chart.
let front = CGRect(x: 175, y: 260, width: 570, height: 420)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(0x10093A, 0.35))
context.beginTransparencyLayer(auxiliaryInfo: nil)
fillBubble(front, radius: 130, tailOnLeft: true, color: color(0xFFFFFF))
context.endTransparencyLayer()
context.restoreGState()

let barWidth: CGFloat = 86
let gap: CGFloat = 42
let baseY = front.minY + 100
let heights: [CGFloat] = [105, 175, 245]
let startX = front.midX - (barWidth * 3 + gap * 2) / 2
let barGradient = gradient([color(0x0E9F8E), color(0x3A2D9E)])
for (index, height) in heights.enumerated() {
    let rect = CGRect(x: startX + CGFloat(index) * (barWidth + gap), y: baseY, width: barWidth, height: height)
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 26, cornerHeight: 26, transform: nil))
    context.clip()
    context.drawLinearGradient(barGradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.minY + 260), options: [])
    context.restoreGState()
}

let image = context.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
print("Wrote \(url.path)")
