// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopOfMind",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TopOfMindApp", targets: ["TopOfMindApp"]),
        .library(name: "TopOfMindCore", targets: ["TopOfMindCore"])
    ],
    targets: [
        .target(name: "TopOfMindCore"),
        .executableTarget(
            name: "TopOfMindApp",
            dependencies: ["TopOfMindCore"],
            path: "App",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SwiftUI"), .linkedFramework("ServiceManagement")]
        ),
        .testTarget(name: "TopOfMindCoreTests", dependencies: ["TopOfMindCore"])
    ]
)
