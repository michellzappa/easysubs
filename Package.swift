// swift-tools-version: 6.0

import PackageDescription

// The subtitle engine behind the EasySubs drop app, as a library so Cargo can
// fetch subtitles after it organizes a file. The app target lives in project.yml.
let package = Package(
    name: "EasySubsKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "EasySubsKit", targets: ["EasySubsKit"])
    ],
    targets: [
        .target(name: "EasySubsKit", path: "Sources/EasySubsKit"),
        .testTarget(name: "EasySubsKitTests", dependencies: ["EasySubsKit"], path: "Tests/EasySubsKitTests")
    ]
)
