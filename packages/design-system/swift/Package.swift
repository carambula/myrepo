// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MinAppKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "MinAppKit",
            targets: ["MinAppKit"]
        )
    ],
    targets: [
        .target(
            name: "MinAppKit",
            path: "Sources/MinAppKit",
            linkerSettings: [
                .linkedFramework("CoreMotion", .when(platforms: [.iOS]))
            ]
        )
    ]
)
