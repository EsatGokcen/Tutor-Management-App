import AppKit
import Foundation

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = projectRoot.appendingPathComponent("App/AppIcon.iconset", isDirectory: true)

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSizes: [(name: String, dimension: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIconArtwork(size: CGFloat) {
    let canvasRect = NSRect(origin: .zero, size: NSSize(width: size, height: size))
    let tileInset = size * 0.085
    let tileRect = canvasRect.insetBy(dx: tileInset, dy: tileInset)
    let cornerRadius = tileRect.width * 0.245
    let backgroundPath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.35)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.016)
    shadow.set()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.91, blue: 0.56, alpha: 1.0),
        NSColor(calibratedRed: 0.06, green: 0.53, blue: 0.32, alpha: 1.0),
        NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.12, alpha: 1.0)
    ])!
    gradient.draw(in: backgroundPath, angle: -38)

    NSGraphicsContext.current?.saveGraphicsState()
    let highlightRect = tileRect.insetBy(dx: tileRect.width * 0.045, dy: tileRect.height * 0.045)
    let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: cornerRadius * 0.92, yRadius: cornerRadius * 0.92)
    highlightPath.addClip()
    let highlightGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.20),
        NSColor(calibratedWhite: 1, alpha: 0.03),
        NSColor(calibratedWhite: 1, alpha: 0.0)
    ])!
    highlightGradient.draw(in: highlightRect, angle: 90)
    NSGraphicsContext.current?.restoreGraphicsState()

    let lineInset = max(1, size * 0.012)
    let linePath = NSBezierPath(
        roundedRect: tileRect.insetBy(dx: lineInset, dy: lineInset),
        xRadius: cornerRadius * 0.94,
        yRadius: cornerRadius * 0.94
    )
    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    linePath.lineWidth = max(1, size * 0.01)
    linePath.stroke()

    let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: tileRect.width * 0.55, weight: .bold)
    let symbol = NSImage(
        systemSymbolName: "graduationcap.circle.fill",
        accessibilityDescription: "TutorTable"
    )?
        .withSymbolConfiguration(symbolConfiguration)

    if let symbol {
        let symbolSize = tileRect.width * 0.62
        let symbolRect = NSRect(
            x: tileRect.midX - (symbolSize / 2),
            y: tileRect.midY - (symbolSize / 2) - (size * 0.01),
            width: symbolSize,
            height: symbolSize
        )
        symbol.draw(
            in: symbolRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: nil
        )
    }
}

func pngData(for size: CGFloat) -> Data? {
    let pixelSize = Int(size.rounded())
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    bitmap.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    drawIconArtwork(size: size)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])
}

for icon in iconSizes {
    let outputURL = iconsetURL.appendingPathComponent(icon.name)
    guard let data = pngData(for: icon.dimension) else {
        throw NSError(domain: "TutorTableIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(icon.name)"])
    }

    try data.write(to: outputURL)
}

print("Generated iconset at \(iconsetURL.path)")
