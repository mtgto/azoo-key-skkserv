// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux) && arch(arm64)
let linkerSettings = [
    LinkerSetting.unsafeFlags(["-L", "./lib/arm64", "-L", "/usr/lib/swift/linux", "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/lib"])
]
#elseif os(Linux) && arch(x86_64)
let linkerSettings = [
    LinkerSetting.unsafeFlags(["-L", "./lib/x86_64", "-L", "/usr/lib/swift/linux", "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/lib"])
]
#else
let linkerSettings: [LinkerSetting] = []
#endif

let package = Package(
    name: "azoo-key-skkserv",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(name: "Core", path: "./Core"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "azoo-key-skkserv",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            linkerSettings: linkerSettings
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                .product(name: "Core", package: "Core"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
        )
    ]
)
