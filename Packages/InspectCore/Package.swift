// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InspectCore",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "InspectCore", targets: ["InspectCore"]),
        .library(name: "InspectFeature", targets: ["InspectFeature"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.18.0"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.5.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.2.0")
    ],
    targets: [
        .target(
            name: "InspectCore",
            dependencies: [
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "Sources/Core"
        ),
        .target(
            name: "InspectFeature",
            dependencies: ["InspectCore"],
            path: "Sources/Feature"
        ),
        .testTarget(
            name: "InspectCoreTests",
            dependencies: [
                "InspectCore",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "Tests/CoreTests",
            resources: [
                .copy("Fixtures/mac_dev.cer")
            ]
        ),
        .testTarget(
            name: "InspectFeatureTests",
            dependencies: [
                "InspectFeature",
                "InspectCore"
            ],
            path: "Tests/FeatureTests"
        )
    ]
)
