// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PeggyTools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PeggyTools",
            targets: ["PeggyTools"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PeggyTools",
            path: "PeggyTools",
            exclude: [
                "Info.plist",
                "Resources"
            ]
        ),
        .testTarget(
            name: "PeggyToolsTests",
            dependencies: ["PeggyTools"],
            path: "PeggyToolsTests"
        )
    ]
)
