// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SkarbSDK",
  platforms: [
    .iOS("11.2"),
  ],
  products: [
    .library(
      name: "SkarbSDK",
      targets: ["SkarbSDK"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/grpc/grpc-swift", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/ashleymills/Reachability.swift", .upToNextMajor(from: "5.1.0"))
  ],
  targets: [
    .target(
      name: "SkarbSDK",
      dependencies: [
        .product(name: "GRPC", package: "grpc-swift"),
        .product(name: "Reachability", package: "Reachability.swift")
      ],
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("AdSupport"),
        .linkedFramework("UIKit"),
        .linkedFramework("StoreKit")
      ]),
    
  ]
)
