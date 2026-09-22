// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StarButlerCompanion",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "StarButlerCompanion",
            targets: ["StarButlerCompanion"]
        )
    ],
    targets: [
        .executableTarget(
            name: "StarButlerCompanion",
            path: "Sources"
        )
    ]
)
