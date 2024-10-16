// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SkarbSDK",
  platforms: [
    .iOS("11.3"),
  ],
  products: [
    .library(
      name: "SkarbSDK",
      targets: ["SkarbSDK"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/grpc/grpc-swift", .upToNextMajor(from: "1.23.1")),
    .package(name: "SwiftProtobuf", url: "https://github.com/apple/swift-protobuf.git", .upToNextMajor(from: "1.28.1")),
    .package(name: "Reachability", url: "https://github.com/ashleymills/Reachability.swift", .upToNextMajor(from: "5.2.4")),
  ],
  targets: [
    .target(
      name: "SkarbSDK",
      dependencies: [
        .product(name: "GRPC", package: "grpc-swift"),
        .product(name: "Reachability", package: "Reachability"),
        .product(name: "SwiftProtobuf", package: "SwiftProtobuf")
      ],
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("AdSupport"),
        .linkedFramework("UIKit"),
        .linkedFramework("StoreKit"),
        .linkedFramework("AdServices"),
        .linkedFramework("AppTrackingTransparency")
      ]),
    
  ]
)
