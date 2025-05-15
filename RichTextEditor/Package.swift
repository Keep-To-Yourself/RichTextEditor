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
    targets: [
        .target(
            name: "RichTextEditor",
            dependencies: []
        ),
        .testTarget(
            name: "RichTextEditorTests",
            dependencies: ["RichTextEditor"]
        )
    ]
)
