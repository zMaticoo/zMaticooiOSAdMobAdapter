// swift-tools-version:5.3
//
// Google Mobile Ads 官方 SPM 最低 iOS 13。
//
import PackageDescription

let package = Package(
    name: "AdMobzMaticooAdapter",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AdMobzMaticooAdapter",
            targets: ["AdMobzMaticooAdapter"]
        )
    ],
    dependencies: [
        .package(name: "zMaticoo", url: "https://github.com/cloudadrd/zMaticooPodSpec.git", from: "2.3.1"),
        .package(
            name: "GoogleMobileAds",
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "13.0.0"
        )
    ],
    targets: [
        .target(
            name: "AdMobzMaticooAdapter",
            dependencies: [
                .product(name: "MaticooSDK", package: "zMaticoo"),
                .product(name: "GoogleMobileAds", package: "GoogleMobileAds")
            ],
            path: "Classes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
