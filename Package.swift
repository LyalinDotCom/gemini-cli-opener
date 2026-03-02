// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GeminiCLIOpener",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "GeminiCLIOpener",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../Resources/Info.plist"),
                .process("../Resources/Assets.xcassets")
            ]
        )
    ]
)
