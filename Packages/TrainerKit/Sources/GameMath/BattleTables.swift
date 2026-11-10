import Foundation

/// PvE (raid/gym) battle data extracted from PokeMiners' game master by scripts/update-level-tables.ps1:
/// type chart, weather boosts, battle multipliers and PvE move stats. See `source` for the commit.
public struct BattleTables: Decodable, Sendable {
    public struct PvEMove: Decodable, Sendable, Hashable, Identifiable {
        /// Same id format as PvPoke ("VINE_WHIP"; the game master's "_FAST" suffix is removed).
        public let id: String
        public let fast: Bool
        public let type: String
        public let power: Double
        public let durationMs: Int
        public let damageWindowStartMs: Int
        /// Positive for fast moves (energy gained), negative for charged moves (energy cost).
        public let energyDelta: Int
    }

    public let source: LevelTables.Source
    /// Defender order of each type chart row.
    public let typeOrder: [String]
    /// Attacking type -> multiplier against each defending type (in `typeOrder`).
    public let typeChart: [String: [Double]]
    /// Weather condition ("clear", "rainy", ...) -> types it boosts.
    public let weatherBoosts: [String: [String]]
    public let sameTypeAttackBonus: Double
    public let weatherAttackBonus: Double
    public let shadowAttackMultiplier: Double
    public let shadowDefenseMultiplier: Double
    public let maximumEnergy: Int
    public let moves: [PvEMove]

    private let movesById: [String: PvEMove]

    enum CodingKeys: String, CodingKey {
        case source, typeOrder, typeChart, weatherBoosts, sameTypeAttackBonus, weatherAttackBonus
        case shadowAttackMultiplier, shadowDefenseMultiplier, maximumEnergy, moves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(LevelTables.Source.self, forKey: .source)
        typeOrder = try c.decode([String].self, forKey: .typeOrder)
        typeChart = try c.decode([String: [Double]].self, forKey: .typeChart)
        weatherBoosts = try c.decode([String: [String]].self, forKey: .weatherBoosts)
        sameTypeAttackBonus = try c.decode(Double.self, forKey: .sameTypeAttackBonus)
        weatherAttackBonus = try c.decode(Double.self, forKey: .weatherAttackBonus)
        shadowAttackMultiplier = try c.decode(Double.self, forKey: .shadowAttackMultiplier)
        shadowDefenseMultiplier = try c.decode(Double.self, forKey: .shadowDefenseMultiplier)
        maximumEnergy = try c.decode(Int.self, forKey: .maximumEnergy)
        moves = try c.decode([PvEMove].self, forKey: .moves)
        movesById = Dictionary(moves.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static func bundled() throws -> BattleTables {
        guard let url = Bundle.module.url(forResource: "battle-tables", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(BattleTables.self, from: Data(contentsOf: url))
    }

    public func move(_ id: String) -> PvEMove? { movesById[id] }

    /// Multiplier of an attack type against a (single or dual type) defender. Unknown types count as 1.
    public func effectiveness(of attackType: String, against defenderTypes: [String]) -> Double {
        guard let row = typeChart[attackType.lowercased()] else { return 1 }
        return defenderTypes.reduce(1) { product, defender in
            guard let index = typeOrder.firstIndex(of: defender.lowercased()), index < row.count else { return product }
            return product * row[index]
        }
    }

    public func isBoosted(_ type: String, in weather: String?) -> Bool {
        guard let weather else { return false }
        return weatherBoosts[weather.lowercased()]?.contains(type.lowercased()) ?? false
    }

    /// Weather conditions in display order.
    public var weatherConditions: [String] { weatherBoosts.keys.sorted() }
}
