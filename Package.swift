// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ESTabBarController",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "ESTabBarController",  targets: ["ESTabBarController"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ESTabBarController",
            path: "Sources",
            resources: [.process("en.lproj")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
