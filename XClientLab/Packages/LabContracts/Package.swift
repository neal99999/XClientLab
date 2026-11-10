// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LabContracts",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "LabContracts", targets: ["LabContracts"]),
    ],
    targets: [
        .target(name: "LabContracts"),
    ],
    swiftLanguageModes: [.v5]
)
