// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PathstaCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "PathstaCore", targets: ["PathstaCore"])
  ],
  targets: [
    .target(name: "PathstaCore", path: "Sources/PathstaCore"),
    .testTarget(
      name: "PathstaTests",
      dependencies: ["PathstaCore"],
      path: "Tests/PathstaTests"
    ),
  ]
)
