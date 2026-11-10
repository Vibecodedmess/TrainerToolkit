import Foundation

/// Per-level tables extracted from PokeMiners' game master by scripts/update-level-tables.ps1.
/// See `source` (and DATA_SOURCES.md) for the exact commit the numbers came from.
public struct LevelTables: Decodable, Sendable {
    public struct Source: Decodable, Sendable {
        public let name: String
        public let url: String
        public let commit: String
        public let extracted: String
        public let templates: [String]
    }

    public let source: Source
    /// CP multiplier for whole levels: index 0 = level 1. Half levels are derived (see CPCalculator).
    public let cpMultiplier: [Double]
    /// Power-ups per whole level (2: L -> L+0.5 -> L+1).
    public let upgradesPerLevel: Int
    /// Highest level reachable by powering up.
    public let maxNormalUpgradeLevel: Int
    /// Extra levels a Best Buddy gets (CP boost, no cost).
    public let bestBuddyExtraLevels: Int
    /// Stardust per power-up while at whole level L: index L-1.
    public let stardustCost: [Int]
    /// Candy per power-up while at whole level L: index L-1. 0 from level 40 (XL Candy instead).
    public let candyCost: [Int]
    /// XL Candy per power-up while at whole level L: index L - xlCandyMinPokemonLevel.
    public let xlCandyCost: [Int]
    public let xlCandyMinPokemonLevel: Int
    public let shadowStardustMultiplier: Double
    public let shadowCandyMultiplier: Double
    public let purifiedStardustMultiplier: Double
    public let purifiedCandyMultiplier: Double
    /// Share of the stardust cost a lucky Pokémon pays (0.5 = half price).
    public let luckyStardustDiscount: Double

    public var maxUpgradeLevel: PokemonLevel { PokemonLevel(Double(maxNormalUpgradeLevel)) }
    public var maxBestBuddyLevel: PokemonLevel { PokemonLevel(Double(maxNormalUpgradeLevel + bestBuddyExtraLevels)) }

    public static func bundled() throws -> LevelTables {
        guard let url = Bundle.module.url(forResource: "level-tables", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(LevelTables.self, from: Data(contentsOf: url))
    }
}
