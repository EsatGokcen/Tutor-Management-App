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

func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }

    return bitmap.representation(using: .png, properties: [:])
}

func makeIconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: image.size)
    let cornerRadius = size * 0.23
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.35)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.91, blue: 0.56, alpha: 1.0),
        NSColor(calibratedRed: 0.06, green: 0.53, blue: 0.32, alpha: 1.0),
        NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.12, alpha: 1.0)
    ])!
    gradient.draw(in: backgroundPath, angle: -38)

    NSGraphicsContext.current?.saveGraphicsState()
    let highlightRect = rect.insetBy(dx: size * 0.04, dy: size * 0.04)
    let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: cornerRadius * 0.9, yRadius: cornerRadius * 0.9)
    highlightPath.addClip()
    let highlightGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.20),
        NSColor(calibratedWhite: 1, alpha: 0.03),
        NSColor(calibratedWhite: 1, alpha: 0.0)
    ])!
    highlightGradient.draw(in: highlightRect, angle: 90)
    NSGraphicsContext.current?.restoreGraphicsState()

    let linePath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.01, dy: size * 0.01), xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    linePath.lineWidth = max(1, size * 0.01)
    linePath.stroke()

    let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size * 0.58, weight: .bold)
    let symbol = NSImage(
        systemSymbolName: "graduationcap.circle.fill",
        accessibilityDescription: "TutorTable"
    )?
        .withSymbolConfiguration(symbolConfiguration)

    if let symbol {
        let symbolRect = NSRect(
            x: size * 0.17,
            y: size * 0.17,
            width: size * 0.66,
            height: size * 0.66
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

    image.unlockFocus()
    return image
}

for icon in iconSizes {
    let image = makeIconImage(size: icon.dimension)
    let outputURL = iconsetURL.appendingPathComponent(icon.name)
    guard let data = pngData(from: image) else {
        throw NSError(domain: "TutorTableIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(icon.name)"])
    }

    try data.write(to: outputURL)
}

print("Generated iconset at \(iconsetURL.path)")
