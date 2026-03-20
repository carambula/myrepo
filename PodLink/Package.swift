// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PodLink",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "PodLink", targets: ["PodLink"])
    ],
    targets: [
        .target(
            name: "PodLink",
            path: "PodLink",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
