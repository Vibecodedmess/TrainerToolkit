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
        .library(name: "Counters", targets: ["Counters"]),
        .library(name: "ScreenshotImport", targets: ["ScreenshotImport"]),
        .library(name: "BackupFormat", targets: ["BackupFormat"]),
    ],
    targets: [
        .target(
            name: "GameMath",
            resources: [.copy("Resources/level-tables.json"), .copy("Resources/battle-tables.json"),
                        .copy("Resources/trade-tables.json"), .copy("Resources/evolution-tables.json"),
                        .copy("Resources/evolution-items-community.json")]
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
        // CSV import for My Collection, in the app's own documented format (COLLECTION_IMPORT.md).
        .target(name: "CollectionImport", dependencies: ["DataSources", "GameMath"]),
        .testTarget(name: "CollectionImportTests", dependencies: ["CollectionImport", "DataSources", "GameMath"]),
        // Raid and Rocket counter rankings (gamemaster species + PvE battle math).
        .target(name: "Counters", dependencies: ["DataSources", "GameMath"],
                resources: [.copy("Resources/raid-tiers.json"), .copy("Resources/rocket-quotes.json")]),
        .testTarget(name: "CountersTests", dependencies: ["Counters", "DataSources", "GameMath"]),
        // Pokémon screenshots -> species, level, IVs, moves (text from Vision in the app; bars from pixels).
        .target(name: "ScreenshotImport", dependencies: ["DataSources", "GameMath"]),
        .testTarget(name: "ScreenshotImportTests", dependencies: ["ScreenshotImport", "DataSources", "GameMath"]),
        // Backup file format (plain Codable values; the app maps its SwiftData models to it).
        .target(name: "BackupFormat"),
        .testTarget(name: "BackupFormatTests", dependencies: ["BackupFormat"]),
    ]
)
