// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hyphen",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "hyphen", targets: ["hyphen"])
    ],
    targets: [
        .binaryTarget(
            name: "libhyphen",
            path: "libhyphen.xcframework"
        ),
        .target(
            name: "hyphen",
            dependencies: ["libhyphen"],
            cSettings: [
                .unsafeFlags([
                    "-Wno-shorten-64-to-32",
                    "-Wno-sign-conversion",
                    "-Wno-implicit-int-conversion",
                ])
            ]
        )
    ]
)
