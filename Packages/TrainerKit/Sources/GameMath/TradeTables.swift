import Foundation

/// Friendship and trade data extracted from PokeMiners' game master by scripts/update-trade-tables.ps1
/// (templates FRIENDSHIP_LEVEL_<n> and REMOTE_TRADE_SETTINGS). See `source` for the commit.
///
/// Not in the game master, so not here: the **base** stardust cost of a trade (the user types it in)
/// and the friendship level names (the app labels levels by number).
public struct TradeTables: Decodable, Sendable {
    /// One FRIENDSHIP_LEVEL_<n> template (`friendshipMilestoneSettings`). Missing values are nil.
    public struct FriendshipLevel: Decodable, Sendable, Hashable, Identifiable {
        public let level: Int
        /// Missing on level 0 in the game master.
        public let minPointsToReach: Int?
        /// Only on some levels (it is on the last one in the pinned data).
        public let relativePointsToReach: Int?
        public let milestoneXpReward: Int?
        /// Named "attackBonusPercentage" in the game master, but the values are multipliers (1.0 on level 0).
        public let attackBonusPercentage: Double?
        public let raidBallBonus: Int?
        /// Share of the trade stardust cost that is taken off (nil = no discount).
        public let tradingDiscount: Double?
        /// Game master trade category ids this level allows, e.g. "REGULAR_IN_POKEDEX".
        public let unlockedTrading: [String]
        public let unlockedLuckyFriendApplicator: Bool

        public var id: Int { level }
    }

    /// REMOTE_TRADE_SETTINGS (`remoteTradeSettings`), copied as-is. Every value is optional.
    public struct RemoteTradeSettings: Decodable, Sendable, Hashable {
        public let enabled: Bool?
        public let requestedPokemonCount: Int?
        public let pokemonUntradableDays: Int?
        public let maxRemoteTradesPerDay: Int?
        public let taggingUnlockPointThreshold: Int?
        public let tradeExpiryReminderMinutes: Int?
        public let timeLimitMinutes: Int?
    }

    public let source: LevelTables.Source
    /// Sorted by level, starting at 0.
    public let friendshipLevels: [FriendshipLevel]
    public let remoteTrade: RemoteTradeSettings?

    enum CodingKeys: String, CodingKey {
        case source, friendshipLevels, remoteTrade
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(LevelTables.Source.self, forKey: .source)
        friendshipLevels = try c.decode([FriendshipLevel].self, forKey: .friendshipLevels).sorted { $0.level < $1.level }
        remoteTrade = try c.decodeIfPresent(RemoteTradeSettings.self, forKey: .remoteTrade)
    }

    public static func bundled() throws -> TradeTables {
        guard let url = Bundle.module.url(forResource: "trade-tables", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(TradeTables.self, from: Data(contentsOf: url))
    }

    /// Highest friendship level in the data (0 if the list is empty).
    public var maxLevel: Int { friendshipLevels.last?.level ?? 0 }

    public func level(_ number: Int) -> FriendshipLevel? {
        friendshipLevels.first { $0.level == number }
    }

    /// Trading discount at a friendship level; 0 when the data gives none.
    public func discount(atLevel number: Int) -> Double {
        level(number)?.tradingDiscount ?? 0
    }

    /// Whether a game master trade category id is unlocked at a friendship level.
    public func isUnlocked(_ categoryId: String, atLevel number: Int) -> Bool {
        level(number)?.unlockedTrading.contains(categoryId) ?? false
    }

    /// Estimated stardust for one trade: the user's base cost minus the friendship discount.
    /// nil when no base cost is known (nil or not positive).
    public func cost(base: Int?, friendshipLevel number: Int) -> Int? {
        guard let base, base > 0 else { return nil }
        return Self.discountedCost(base: base, discount: discount(atLevel: number))
    }

    /// base × (1 − discount), rounded to the nearest whole stardust. Discounts outside 0...1 are clamped.
    /// TODO: verify the rounding against the game (the game master gives only the discount).
    public static func discountedCost(base: Int, discount: Double) -> Int {
        let share = 1 - min(max(discount, 0), 1)
        return Int((Double(base) * share).rounded(.toNearestOrAwayFromZero))
    }

    /// Plain-English label for a game master trade category id, built from the id's words:
    /// "REGULAR_IN_POKEDEX" -> "Regular, registered", "LEGENDARY_NON_POKEDEX" -> "Legendary, not registered".
    /// ("In/non Pokédex" = already / not yet registered in the receiving trainer's Pokédex.)
    public static func readableCategory(_ id: String) -> String {
        var words = id.uppercased().split(separator: "_").map(String.init)
        var suffix: String?
        if words.count >= 2, words[words.count - 1] == "POKEDEX" {
            let marker = words[words.count - 2]
            if marker == "IN" { suffix = "registered" } else if marker == "NON" { suffix = "not registered" }
            if suffix != nil { words.removeLast(2) }
        }
        let names: [String: String] = ["GMAX": "Gigantamax"]
        let head = capitalizedFirst(words.map { names[$0] ?? $0.lowercased() }.joined(separator: " "))
        guard let suffix else { return head.isEmpty ? id : head }
        return head.isEmpty ? capitalizedFirst(suffix) : "\(head), \(suffix)"
    }

    private static func capitalizedFirst(_ text: String) -> String {
        String(text.prefix(1)).uppercased() + String(text.dropFirst())
    }
}
