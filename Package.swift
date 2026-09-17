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
    // grpc-swift's public initializers (CallOptions/ClientConnection.Configuration) carry
    // default arguments that emit references to these transitive modules into the CALLER.
    // Declaring them here makes SkarbSDK link them directly, so its (dynamic) framework link
    // resolves Logging / NIOSSL / NIOHPACK / NIOCore symbols instead of leaving them undefined.
    .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.0")),
    .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.65.0")),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMajor(from: "2.26.0")),
    .package(url: "https://github.com/apple/swift-nio-http2.git", .upToNextMajor(from: "1.34.0")),
  ],
  targets: [
    .target(
      name: "SkarbSDK",
      dependencies: [
        .product(name: "GRPC", package: "grpc-swift"),
        .product(name: "Reachability", package: "Reachability"),
        .product(name: "SwiftProtobuf", package: "SwiftProtobuf"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "NIOHTTP2", package: "swift-nio-http2")
      ],
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("AdSupport"),
        .linkedFramework("UIKit"),
        .linkedFramework("StoreKit"),
        .linkedFramework("AdServices"),
        .linkedFramework("AppTrackingTransparency")
      ]),
    .testTarget(
      name: "SkarbSDKTests",
      dependencies: ["SkarbSDK"]),
    
  ]
)
