// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LabFeatureKit",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "LabFeatureKit", targets: ["LabFeatureKit"]),
    ],
    dependencies: [
        .package(path: "../LabContracts"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.12.0")),
    ],
    targets: [
        .target(
            name: "LabFeatureKit",
            dependencies: [
                "LabContracts",
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            resources: [.process("Resources")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
