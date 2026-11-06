// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TerritoryCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "TerritoryCore", targets: ["TerritoryCore"])],
    targets: [
        .target(name: "TerritoryCore"),
        .testTarget(name: "TerritoryCoreTests", dependencies: ["TerritoryCore"])
    ]
)
