// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DiscoverBuds",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DiscoverBuds",
            path: "Sources/DiscoverBuds",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DiscoverBuds/Info.plist"
                ])
            ]
        )
    ]
)
