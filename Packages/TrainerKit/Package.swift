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
        .library(name: "SearchBuilder", targets: ["SearchBuilder"]),
        .library(name: "CollectionImport", targets: ["CollectionImport"]),
    ],
    targets: [
        .target(
            name: "GameMath",
            resources: [.copy("Resources/level-tables.json"), .copy("Resources/battle-tables.json")]
        ),
        .target(
            name: "DataSources",
            resources: [.copy("Snapshots")]
        ),
        .target(
            name: "SearchBuilder",
            resources: [.copy("Resources/search-terms.json")]
        ),
        // DataSources is a test-only dependency: tests cross-check CP math against PvPoke's data.
        .testTarget(name: "GameMathTests", dependencies: ["GameMath", "DataSources"]),
        .testTarget(name: "DataSourcesTests", dependencies: ["DataSources"]),
        .testTarget(name: "SearchBuilderTests", dependencies: ["SearchBuilder"]),
        // CSV import for My Collection. The Poke Genie column mapping comes after seeing a real export.
        .target(name: "CollectionImport"),
        .testTarget(name: "CollectionImportTests", dependencies: ["CollectionImport"]),
    ]
)
