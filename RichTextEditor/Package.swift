// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RichTextEditor",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "RichTextEditor",
            targets: ["RichTextEditor"]
        ),
    ],
    dependencies: [
      .package(
        url: "https://github.com/apple/swift-collections.git",
        .upToNextMinor(from: "1.1.0") // or `.upToNextMajor
      )
    ],
    targets: [
        .target(
            name: "RichTextEditor",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "RichTextEditorTests",
            dependencies: ["RichTextEditor"]
        )
    ]
)
