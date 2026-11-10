import Foundation

// Models for ScrapedDuck's feeds (https://github.com/bigfoott/ScrapedDuck, `data` branch).
// Data is scraped from LeekDuck.com. Field names follow the ScrapedDuck wiki.
// The feeds contain `image` URLs. They are deliberately NOT decoded: the app never shows
// or loads official artwork.

public struct SDEvent: Decodable, Sendable, Hashable, Identifiable {
    public let eventID: String
    public let name: String
    public let eventType: String
    public let heading: String?
    public let link: String?
    /// ISO 8601. Ends in "Z" for global (UTC) times, has no zone for local times.
    public let start: String?
    public let end: String?
    public let extraData: JSONValue?

    public var id: String { eventID }
    public var startTime: EventTime? { start.flatMap(EventTime.init(isoString:)) }
    public var endTime: EventTime? { end.flatMap(EventTime.init(isoString:)) }

    public static func == (lhs: SDEvent, rhs: SDEvent) -> Bool { lhs.eventID == rhs.eventID }
    public func hash(into hasher: inout Hasher) { hasher.combine(eventID) }
}

public struct SDNamed: Decodable, Sendable, Hashable {
    public let name: String
}

public struct SDCPRange: Decodable, Sendable, Hashable {
    public let min: Int
    public let max: Int
}

public struct SDRaidBoss: Decodable, Sendable, Hashable {
    public struct CombatPower: Decodable, Sendable, Hashable {
        public let normal: SDCPRange?
        public let boosted: SDCPRange?
    }

    public let name: String
    /// For example "5-Star Raids".
    public let tier: String
    public let canBeShiny: Bool?
    public let types: [SDNamed]?
    public let combatPower: CombatPower?
    public let boostedWeather: [SDNamed]?
}

public struct SDResearchTask: Decodable, Sendable, Hashable {
    public struct Reward: Decodable, Sendable, Hashable {
        public let name: String
        public let canBeShiny: Bool?
        public let combatPower: SDCPRange?
    }

    /// May contain simple HTML tags such as <span>.
    public let text: String
    /// For example "catch", "throw", "battle".
    public let type: String?
    public let rewards: [Reward]?
}

public struct SDRocketLineup: Decodable, Sendable, Hashable {
    public struct Member: Decodable, Sendable, Hashable {
        public let name: String
        public let types: [String]?
        public let isEncounter: Bool?
        public let canBeShiny: Bool?
    }

    /// For example "Giovanni", "Cliff", "Fire-type Female Grunt".
    public let name: String
    /// For example "Team GO Rocket Leader".
    public let title: String?
    /// Grunt type ("fire"), empty for leaders.
    public let type: String?
    public let firstPokemon: [Member]?
    public let secondPokemon: [Member]?
    public let thirdPokemon: [Member]?
}
