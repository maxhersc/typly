// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Typly",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Typly",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])
            ]
        )
    ]
)
