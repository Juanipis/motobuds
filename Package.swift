// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MotoBuds",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Sparkle handles in-app auto-updates: appcast polling, signed
        // download, atomic install, restart. EdDSA signing is enforced
        // by SUPublicEDKey in Bundle/AppInfo.plist.
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "MotoBudsApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/MotoBudsApp",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Bundle/AppInfo.plist",
                ])
            ]
        ),
        .testTarget(
            name: "MotoBudsAppTests",
            dependencies: ["MotoBudsApp"],
            path: "Tests/MotoBudsAppTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
