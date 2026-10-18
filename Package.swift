// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LeaflitCore", platforms: [.macOS(.v14)], products: [.library(name: "LeaflitCore", targets: ["LeaflitCore"])], targets: [.target(name: "LeaflitCore"), .testTarget(name: "LeaflitCoreTests", dependencies: ["LeaflitCore"])])
