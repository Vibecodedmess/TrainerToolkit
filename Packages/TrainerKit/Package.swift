// swift-tools-version:5.9
// Pure-Swift modules (Foundation only, no UIKit/SwiftUI/SwiftData) so they can be
// unit tested with plain `swift test`, on macOS CI or any machine with a Swift toolchain.
import PackageDescription

let package = Package(
    name: "TrainerKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameMath", targets: ["GameMath"]),
        .library(name: "DataSources", targets: ["DataSources"]),
    ],
    targets: [
        .target(name: "GameMath"),
        .target(
            name: "DataSources",
            resources: [.copy("Snapshots")]
        ),
        .testTarget(name: "GameMathTests", dependencies: ["GameMath"]),
        .testTarget(name: "DataSourcesTests", dependencies: ["DataSources"]),
    ]
)
