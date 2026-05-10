// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MotoBuds",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MotoBudsApp",
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
