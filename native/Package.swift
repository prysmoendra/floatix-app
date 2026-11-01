// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Floatix",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FloatixCore", targets: ["FloatixCore"]),
        .executable(name: "Floatix", targets: ["Floatix"]),
        .executable(name: "FloatixChecks", targets: ["FloatixChecks"]),
    ],
    targets: [
        .target(name: "FloatixCore"),
        .executableTarget(name: "Floatix", dependencies: ["FloatixCore"]),
        .executableTarget(name: "FloatixChecks", dependencies: ["FloatixCore"]),
    ]
)
