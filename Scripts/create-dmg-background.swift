import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dmg-background.png")
let canvasSize = NSSize(width: 660, height: 430)

func centeredOrigin(for text: NSAttributedString, y: CGFloat) -> NSPoint {
    let width = text.size().width
    return NSPoint(x: (canvasSize.width - width) / 2, y: y)
}

let image = NSImage(size: canvasSize)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: canvasSize)
NSGradient(
    starting: NSColor(calibratedRed: 0.965, green: 0.978, blue: 1.0, alpha: 1),
    ending: NSColor(calibratedRed: 0.91, green: 0.945, blue: 0.995, alpha: 1)
)?.draw(in: bounds, angle: 90)

let glow = NSBezierPath(ovalIn: NSRect(x: 430, y: 180, width: 300, height: 300))
NSColor(calibratedRed: 0.44, green: 0.35, blue: 1.0, alpha: 0.085).setFill()
glow.fill()

let glowTwo = NSBezierPath(ovalIn: NSRect(x: -120, y: -80, width: 330, height: 330))
NSColor(calibratedRed: 0.05, green: 0.52, blue: 1.0, alpha: 0.09).setFill()
glowTwo.fill()

let title = NSAttributedString(
    string: "Install Prompt Shelf",
    attributes: [
        .font: NSFont.systemFont(ofSize: 26, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
        .kern: -0.5
    ]
)
title.draw(at: centeredOrigin(for: title, y: 362))

let subtitle = NSAttributedString(
    string: "Drag Prompt Shelf to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.39, alpha: 1)
    ]
)
subtitle.draw(at: centeredOrigin(for: subtitle, y: 334))

let arrowColor = NSColor(calibratedRed: 0.08, green: 0.46, blue: 0.93, alpha: 0.82)
arrowColor.setStroke()

let arrow = NSBezierPath()
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 280, y: 205))
arrow.line(to: NSPoint(x: 380, y: 205))
arrow.move(to: NSPoint(x: 361, y: 221))
arrow.line(to: NSPoint(x: 380, y: 205))
arrow.line(to: NSPoint(x: 361, y: 189))
arrow.stroke()

let installLabel = NSAttributedString(
    string: "DRAG TO INSTALL",
    attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.78, alpha: 0.72),
        .kern: 1.4
    ]
)
installLabel.draw(at: centeredOrigin(for: installLabel, y: 165))

let footer = NSAttributedString(
    string: "macOS 13+   •   Apple Silicon + Intel",
    attributes: [
        .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.47, alpha: 1)
    ]
)
footer.draw(at: centeredOrigin(for: footer, y: 28))

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Unable to render DMG background.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
