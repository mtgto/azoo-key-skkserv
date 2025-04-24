// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux) && arch(arm64)
let linkerSettings = [
    LinkerSetting.unsafeFlags(["-L", "./lib/arm64", "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/lib"])
]
#elseif os(Linux) && arch(x86_64)
let linkerSettings = [
    LinkerSetting.unsafeFlags(["-L", "./lib/x86_64", "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/lib"])
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
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", revision: "2cde22d3e2dd67244f7b095e092f23892dd4d566", traits: ["Zenzai"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "azoo-key-skkserv",
            dependencies: [
                .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "AzooKeyKanaKanjiConverter")
            ],
            resources: [
                .copy("zenz-v1.gguf")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            linkerSettings: linkerSettings
        )
    ]
)
