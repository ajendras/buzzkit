// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BuzzKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BuzzKit",
            targets: ["BuzzKit"]
        ),
        .executable(
            name: "haptikit",
            targets: ["haptikit-cli"]
        ),
        .executable(
            name: "BuzzKitDemo",
            targets: ["BuzzKitDemo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "BuzzKit",
            dependencies: []
        ),
        .executableTarget(
            name: "haptikit-cli",
            dependencies: [
                "BuzzKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "BuzzKitDemo",
            dependencies: ["BuzzKit"]
        ),
        .testTarget(
            name: "BuzzKitTests",
            dependencies: ["BuzzKit"]
        )
    ]
)
