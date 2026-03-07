// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Engine2043",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "Engine2043", targets: ["Engine2043"])
    ],
    targets: [
        .target(
            name: "Engine2043",
            resources: [
                .process("Rendering/Shaders")
            ]
        ),
        .testTarget(
            name: "Engine2043Tests",
            dependencies: ["Engine2043"]
        )
    ]
)
