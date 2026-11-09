// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gloss",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Gloss", targets: ["Gloss"]),
        .library(name: "GlossCore", targets: ["GlossCore"]),
    ],
    targets: [
        .target(name: "GlossCore"),
        .executableTarget(
            name: "Gloss",
            dependencies: ["GlossCore"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .testTarget(name: "GlossCoreTests", dependencies: ["GlossCore"]),
    ]
)
