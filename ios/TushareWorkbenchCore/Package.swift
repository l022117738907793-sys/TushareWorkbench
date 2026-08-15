// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TushareWorkbenchCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TushareWorkbenchCore", targets: ["TushareWorkbenchCore"]),
    ],
    targets: [
        .target(
            name: "TushareWorkbenchCore",
            path: "Sources/TushareWorkbenchCore"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["TushareWorkbenchCore"],
            path: "Tests/CoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
