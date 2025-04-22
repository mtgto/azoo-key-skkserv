// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "azoo-key-skkserv",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // TODO: 0.8.0にしたいが, ビルド通らなかったので一旦0.7.0で検証
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", from: "0.7.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "azoo-key-skkserv",
            dependencies: [
                .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "AzooKeyKanaKanjiConverter")
            ]
        )
    ]
)
