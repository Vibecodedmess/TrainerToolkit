import Foundation

/// The parts of PvPoke's gamemaster.json the app uses.
/// Source: https://github.com/pvpoke/pvpoke (MIT). Field meanings follow PvPoke's format.
///
/// Note: move `power`, `energy`, `energyGain`, `cooldown` and `turns` are PvP (trainer battle)
/// values. Raid/gym (PvE) move stats are different and are NOT in this file.
public struct Gamemaster: Decodable, Sendable {
    public let timestamp: String?
    public let pokemon: [GMPokemon]
    public let moves: [GMMove]
    /// Entries that did not match the expected format and were skipped.
    public let skippedEntries: Int
    public let totalEntries: Int

    enum CodingKeys: String, CodingKey {
        case timestamp, pokemon, moves
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        let pokemonList = try container.decode(LossyArray<GMPokemon>.self, forKey: .pokemon)
        let moveList = try container.decode(LossyArray<GMMove>.self, forKey: .moves)
        pokemon = pokemonList.elements
        moves = moveList.elements
        skippedEntries = pokemonList.failures + moveList.failures
        totalEntries = pokemon.count + moves.count + skippedEntries
    }
}

public struct GMPokemon: Decodable, Sendable, Hashable, Identifiable {
    public struct BaseStats: Decodable, Sendable, Hashable {
        public let atk: Int
        public let def: Int
        public let hp: Int
    }

    public struct Family: Decodable, Sendable, Hashable {
        public let id: String?
        public let parent: String?
        public let evolutions: [String]?
    }

    public let dex: Int
    public let speciesId: String
    public let speciesName: String
    public let baseStats: BaseStats
    /// PvPoke uses "none" as the second type of single-type Pokémon. See `realTypes`.
    public let types: [String]
    public let fastMoves: [String]
    public let chargedMoves: [String]
    public let eliteMoves: [String]
    public let legacyMoves: [String]
    public let tags: [String]
    public let released: Bool
    public let family: Family?
    /// PvPoke's CP at level 25 with 0/0/0 IVs (not present for every entry).
    public let level25CP: Int?
    /// PvPoke's rank-1 league IVs: "cp500"/"cp1500"/"cp2500" -> [level, atk, def, sta].
    public let defaultIVs: [String: [Double]]?

    public var id: String { speciesId }
    public var realTypes: [String] { types.filter { $0 != "none" } }

    enum CodingKeys: String, CodingKey {
        case dex, speciesId, speciesName, baseStats, types, fastMoves, chargedMoves
        case eliteMoves, legacyMoves, tags, released, family, level25CP, defaultIVs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dex = try c.decode(Int.self, forKey: .dex)
        speciesId = try c.decode(String.self, forKey: .speciesId)
        speciesName = try c.decode(String.self, forKey: .speciesName)
        baseStats = try c.decode(BaseStats.self, forKey: .baseStats)
        types = try c.decode([String].self, forKey: .types)
        fastMoves = try c.decodeIfPresent([String].self, forKey: .fastMoves) ?? []
        chargedMoves = try c.decodeIfPresent([String].self, forKey: .chargedMoves) ?? []
        eliteMoves = try c.decodeIfPresent([String].self, forKey: .eliteMoves) ?? []
        legacyMoves = try c.decodeIfPresent([String].self, forKey: .legacyMoves) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        released = try c.decodeIfPresent(Bool.self, forKey: .released) ?? true
        family = try c.decodeIfPresent(Family.self, forKey: .family)
        level25CP = try? c.decodeIfPresent(Int.self, forKey: .level25CP)
        defaultIVs = try? c.decodeIfPresent([String: [Double]].self, forKey: .defaultIVs)
    }
}

public struct GMMove: Decodable, Sendable, Hashable, Identifiable {
    public let moveId: String
    public let name: String
    public let type: String
    /// PvP values (see note on `Gamemaster`).
    public let power: Int?
    public let energy: Int?
    public let energyGain: Int?
    public let cooldown: Int?
    public let turns: Int?

    public var id: String { moveId }
    /// Fast moves generate energy, charged moves cost it.
    public var isFastMove: Bool { (energyGain ?? 0) > 0 }
}
