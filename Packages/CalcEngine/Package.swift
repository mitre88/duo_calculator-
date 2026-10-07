// swift-tools-version: 6.0
// CalcEngine — platform-independent calculator core (no UIKit/SwiftUI).
// Builds and tests on Linux, macOS and iOS.
import PackageDescription

let package = Package(
    name: "CalcEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CalcEngine", targets: ["CalcEngine"]),
        .executable(name: "calc", targets: ["calc"]),
    ],
    dependencies: [
        // Arbitrary-precision decimal arithmetic + transcendental functions (MIT).
        .package(url: "https://github.com/mgriebling/BigDecimal.git", from: "3.0.2"),
        // Exact rational numbers (BFraction) and big integers (MIT). Vendored copy of 2.3.0 with a
        // Linux-compatible random source; same identity ("bigint"), so BigDecimal uses it too.
        .package(path: "../Vendor/BigInt"),
    ],
    targets: [
        .target(
            name: "CalcEngine",
            dependencies: [
                .product(name: "BigDecimal", package: "BigDecimal"),
                .product(name: "BigInt", package: "BigInt"),
            ]
        ),
        .executableTarget(
            name: "calc",
            dependencies: ["CalcEngine"]
        ),
        .testTarget(
            name: "CalcEngineTests",
            dependencies: ["CalcEngine"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
