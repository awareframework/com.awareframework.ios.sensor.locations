// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.locations",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.locations",
            targets: [
                "com.awareframework.ios.sensor.locations"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.locations",
            dependencies: [
                .product(
                    name: "com.awareframework.ios.core", package: "com.awareframework.ios.core",
                    condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.locations"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.locationsTests",
            dependencies: [
                .target(name: "com.awareframework.ios.sensor.locations")
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
