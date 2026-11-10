import Foundation

/// Every external dataset the app uses. See DATA_SOURCES.md for licenses and usage notes.
public enum DataSourceID: String, CaseIterable, Codable, Sendable, Identifiable {
    case gamemaster
    case events
    case raids
    case research
    case rocketLineups

    public var id: String { rawValue }

    public var descriptor: DataSourceDescriptor {
        switch self {
        case .gamemaster:
            return DataSourceDescriptor(
                id: self,
                displayName: "Pokémon & moves",
                provider: "PvPoke gamemaster",
                remoteURL: URL(string: "https://raw.githubusercontent.com/pvpoke/pvpoke/master/src/data/gamemaster.min.json")!,
                fileName: "gamemaster.json",
                minimumRefreshInterval: 5 * 60
            )
        case .events:
            return .scrapedDuck(self, displayName: "Events", file: "events")
        case .raids:
            return .scrapedDuck(self, displayName: "Raid bosses", file: "raids")
        case .research:
            return .scrapedDuck(self, displayName: "Field research", file: "research")
        case .rocketLineups:
            return .scrapedDuck(self, displayName: "Rocket lineups", file: "rocketLineups")
        }
    }
}

public struct DataSourceDescriptor: Sendable, Identifiable {
    public let id: DataSourceID
    public let displayName: String
    public let provider: String
    public let remoteURL: URL
    /// File name used for both the bundled snapshot and the downloaded cache copy.
    public let fileName: String
    /// The shortest gap between two network requests that the source asks for.
    /// Manual "Refresh now" respects this too.
    public let minimumRefreshInterval: TimeInterval

    /// ScrapedDuck's wiki (Rate-Limits page) asks not to fetch an endpoint more often
    /// than every 5 minutes, because GitHub caches the raw files for 5 minutes.
    static func scrapedDuck(_ id: DataSourceID, displayName: String, file: String) -> DataSourceDescriptor {
        DataSourceDescriptor(
            id: id,
            displayName: displayName,
            provider: "ScrapedDuck (data from LeekDuck.com)",
            remoteURL: URL(string: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/\(file).min.json")!,
            fileName: "\(file).json",
            minimumRefreshInterval: 5 * 60
        )
    }
}
