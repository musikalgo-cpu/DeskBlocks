// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeskBlocks",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "DeskBlocksPrototype", targets: ["DeskBlocksPrototype"])
    ],
    targets: [
        .target(name: "DeskBlocksCore"),
        .executableTarget(
            name: "DeskBlocksPrototype",
            dependencies: ["DeskBlocksCore"]
        ),
        .executableTarget(
            name: "DeskBlocksCoreChecks",
            dependencies: ["DeskBlocksCore"]
        )
    ]
)
