// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoCoKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "SoCoKit", targets: ["SoCoKit"])
    ],
    targets: [
        .target(name: "SoCoKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "SoCoKitTests",
            dependencies: ["SoCoKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
