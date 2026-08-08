// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PromptShelf",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PromptShelf", targets: ["PromptShelf"])
    ],
    targets: [
        .executableTarget(
            name: "PromptShelf"
        ),
        .testTarget(
            name: "PromptShelfTests",
            dependencies: ["PromptShelf"]
        )
    ]
)
