import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: build-icns.swift <iconset-directory> <output.icns>\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let entries: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { bytes in
            append(contentsOf: bytes)
        }
    }
}

var payload = Data()
for entry in entries {
    guard let type = entry.type.data(using: .ascii), type.count == 4 else {
        fputs("Invalid ICNS entry type: \(entry.type)\n", stderr)
        exit(3)
    }

    let iconURL = iconsetURL.appendingPathComponent(entry.filename)
    let iconData = try Data(contentsOf: iconURL)
    payload.append(type)
    payload.appendBigEndian(UInt32(iconData.count + 8))
    payload.append(iconData)
}

var output = Data("icns".utf8)
output.appendBigEndian(UInt32(payload.count + 8))
output.append(payload)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try output.write(to: outputURL, options: .atomic)
