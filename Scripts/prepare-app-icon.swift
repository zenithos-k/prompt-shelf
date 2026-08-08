import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: prepare-app-icon.swift <source.png> <output.png>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to read source icon.\n", stderr)
    exit(3)
}

let outputSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outputSize,
    pixelsHigh: outputSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create icon canvas.\n", stderr)
    exit(4)
}

let previousContext = NSGraphicsContext.current
NSGraphicsContext.current = context
defer { NSGraphicsContext.current = previousContext }

context.imageInterpolation = .high
context.cgContext.clear(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

sourceImage.draw(
    in: NSRect(x: 0, y: 0, width: outputSize, height: outputSize),
    from: .zero,
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.flushGraphics()

// Image generation previews transparency as a baked-in checkerboard. Remove
// only the bright neutral region connected to an outer edge, preserving the
// white quotation marks and highlights inside the artwork.
if let pixels = bitmap.bitmapData {
    let bytesPerRow = bitmap.bytesPerRow
    let bytesPerPixel = bitmap.bitsPerPixel / 8
    var queue: [Int] = []
    queue.reserveCapacity(outputSize * 8)

    func enqueueBackgroundPixel(x: Int, y: Int) {
        guard x >= 0, x < outputSize, y >= 0, y < outputSize else { return }

        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let alpha = pixels[offset + 3]
        let channelMinimum = min(red, green, blue)
        let channelMaximum = max(red, green, blue)

        guard alpha > 0,
              channelMinimum >= 220,
              channelMaximum - channelMinimum <= 12 else { return }

        pixels[offset + 3] = 0
        queue.append(y * outputSize + x)
    }

    for coordinate in 0..<outputSize {
        enqueueBackgroundPixel(x: coordinate, y: 0)
        enqueueBackgroundPixel(x: coordinate, y: outputSize - 1)
        enqueueBackgroundPixel(x: 0, y: coordinate)
        enqueueBackgroundPixel(x: outputSize - 1, y: coordinate)
    }

    var index = 0
    while index < queue.count {
        let coordinate = queue[index]
        index += 1
        let x = coordinate % outputSize
        let y = coordinate / outputSize

        enqueueBackgroundPixel(x: x - 1, y: y)
        enqueueBackgroundPixel(x: x + 1, y: y)
        enqueueBackgroundPixel(x: x, y: y - 1)
        enqueueBackgroundPixel(x: x, y: y + 1)
    }
}

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon PNG.\n", stderr)
    exit(5)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
