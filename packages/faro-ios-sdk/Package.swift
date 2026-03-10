// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FaroSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "FaroSDK",
            targets: ["FaroSDK"]
        ),
    ],
    targets: [
        .target(
            name: "FaroSDK",
            path: "Sources/FaroSDK"
        ),
        .testTarget(
            name: "FaroSDKTests",
            dependencies: ["FaroSDK"],
            path: "Tests/FaroSDKTests"
        ),
    ]
)
