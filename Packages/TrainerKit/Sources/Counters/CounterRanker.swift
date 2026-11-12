import Foundation
import DataSources
import GameMath

/// A Pokémon that could fight: either a generic species at a chosen level, or one from My Collection.
public struct CounterCandidate: Sendable, Hashable, Identifiable {
    /// Unique per candidate ("generic:mewtwo", or a collection entry's id).
    public let id: String
    public let speciesId: String
    public let name: String
    public let combatant: Combatant
    /// Moves to try. Generic candidates list everything the species can learn; collection entries
    /// list only what the Pokémon actually knows.
    public let fastMoveIds: [String]
    public let chargedMoveIds: [String]
    public let isMine: Bool

    public init(id: String, speciesId: String, name: String, combatant: Combatant,
                fastMoveIds: [String], chargedMoveIds: [String], isMine: Bool) {
        self.id = id
        self.speciesId = speciesId
        self.name = name
        self.combatant = combatant
        self.fastMoveIds = fastMoveIds
        self.chargedMoveIds = chargedMoveIds
        self.isMine = isMine
    }
}

/// One ranked counter: its best moveset against the defender and its DPS relative to the best one.
public struct CounterResult: Sendable, Hashable, Identifiable {
    public let candidate: CounterCandidate
    public let moveset: DamageCalculator.MovesetResult
    /// DPS divided by the DPS of the top result (1 = best). 0…1.
    public let relativeDPS: Double

    public var id: String { candidate.id }
}

/// How strongly one attacking type hits a defender.
public struct TypeMultiplier: Sendable, Hashable, Identifiable {
    public let type: String
    public let multiplier: Double
    public var id: String { type }
}

/// Raid / Rocket counter rankings.
///
/// The defender is built from its species' base stats at a stand-in level, because raid boss and
/// Rocket Pokémon stat multipliers are held by the game's servers and are not in any data source
/// the app uses. Defense only scales every attacker's damage by the same factor, so the ranking
/// (and `relativeDPS`) barely depends on that choice; absolute DPS numbers are not shown for that reason.
public enum CounterRanker {
    /// Level used for defenders whose real stats are unknown (raid bosses, Rocket Pokémon).
    public static let standInDefenderLevel = PokemonLevel(40)
    public static let standInDefenderIVs = IVs(attack: 15, defense: 15, stamina: 15)

    public static func defender(_ pokemon: GMPokemon, isShadow: Bool = false) -> Combatant {
        Combatant(base: pokemon.stats,
                  ivs: standInDefenderIVs, level: standInDefenderLevel, types: pokemon.realTypes,
                  isShadow: isShadow || isShadowEntry(pokemon))
    }

    /// Ranks candidates by the DPS of their best moveset. Candidates without usable PvE move data are left out.
    public static func rank(_ candidates: [CounterCandidate], against defender: Combatant, weather: String?,
                            levels: LevelTables, battle: BattleTables, limit: Int? = nil) -> [CounterResult] {
        var scored: [(CounterCandidate, DamageCalculator.MovesetResult)] = []
        scored.reserveCapacity(candidates.count)
        for c in candidates {
            guard let best = DamageCalculator.bestMoveset(attacker: c.combatant, fastMoveIds: c.fastMoveIds,
                                                          chargedMoveIds: c.chargedMoveIds, defender: defender,
                                                          weather: weather, levels: levels, battle: battle),
                  best.dps > 0 else { continue }
            scored.append((c, best))
        }
        // Highest DPS first; ties by name, then id, so the order is stable.
        scored.sort {
            if $0.1.dps != $1.1.dps { return $0.1.dps > $1.1.dps }
            if $0.0.name != $1.0.name { return $0.0.name < $1.0.name }
            return $0.0.id < $1.0.id
        }
        let top = scored.first?.1.dps ?? 1
        let kept = limit.map { Array(scored.prefix($0)) } ?? scored
        return kept.map { CounterResult(candidate: $0.0, moveset: $0.1, relativeDPS: top > 0 ? $0.1.dps / top : 0) }
    }

    /// Ranks candidates against several possible defenders (for example the 3 Pokémon a Rocket
    /// leader might use in one slot): score = average `relativeDPS` over the defenders.
    public static func rankAgainstAll(_ candidates: [CounterCandidate], defenders: [Combatant], weather: String?,
                                      levels: LevelTables, battle: BattleTables, limit: Int? = nil) -> [(candidate: CounterCandidate, score: Double)] {
        guard !defenders.isEmpty else { return [] }
        var total: [String: Double] = [:]
        var byId: [String: CounterCandidate] = [:]
        for d in defenders {
            for r in rank(candidates, against: d, weather: weather, levels: levels, battle: battle) {
                total[r.candidate.id, default: 0] += r.relativeDPS
                byId[r.candidate.id] = r.candidate
            }
        }
        let n = Double(defenders.count)
        let sorted = total.map { (candidate: byId[$0.key]!, score: $0.value / n) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.candidate.name != $1.candidate.name { return $0.candidate.name < $1.candidate.name }
                return $0.candidate.id < $1.candidate.id
            }
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }

    // MARK: - Candidate pools

    public struct GenericOptions: Hashable, Sendable {
        public var level: PokemonLevel
        public var ivs: IVs
        public var includeShadow: Bool
        public var includeMega: Bool
        /// Elite TM / legacy moves (PvPoke's eliteMoves + legacyMoves).
        public var includeSpecialMoves: Bool

        public init(level: PokemonLevel = PokemonLevel(40), ivs: IVs = IVs(attack: 15, defense: 15, stamina: 15),
                    includeShadow: Bool = true, includeMega: Bool = false, includeSpecialMoves: Bool = true) {
            self.level = level
            self.ivs = ivs
            self.includeShadow = includeShadow
            self.includeMega = includeMega
            self.includeSpecialMoves = includeSpecialMoves
        }
    }

    /// Every released species (per PvPoke) as a generic attacker.
    public static func genericCandidates(_ gamemaster: Gamemaster, options: GenericOptions) -> [CounterCandidate] {
        var seen: Set<String> = []
        var result: [CounterCandidate] = []
        for p in gamemaster.pokemon where p.released && !seen.contains(p.speciesId) {
            let shadow = isShadowEntry(p)
            let mega = isMegaEntry(p)
            if shadow && !options.includeShadow { continue }
            if mega && !options.includeMega { continue }
            seen.insert(p.speciesId)
            let special = Set(p.eliteMoves + p.legacyMoves)
            let allowed: (String) -> Bool = { options.includeSpecialMoves || !special.contains($0) }
            let fast = unique(p.fastMoves + (options.includeSpecialMoves ? p.eliteMoves + p.legacyMoves : [])).filter(allowed)
            let charged = unique(p.chargedMoves + (options.includeSpecialMoves ? p.eliteMoves + p.legacyMoves : [])).filter(allowed)
            guard !fast.isEmpty else { continue }
            let base = p.stats
            result.append(CounterCandidate(
                id: "generic:\(p.speciesId)", speciesId: p.speciesId, name: p.speciesName,
                combatant: Combatant(base: base, ivs: options.ivs, level: options.level, types: p.realTypes, isShadow: shadow),
                fastMoveIds: fast, chargedMoveIds: charged, isMine: false))
        }
        return result
    }

    // MARK: - Types

    /// Attack types that hit the defender harder than neutral, strongest first.
    public static func weaknesses(of defenderTypes: [String], battle: BattleTables) -> [TypeMultiplier] {
        multipliers(defenderTypes, battle: battle).filter { $0.multiplier > 1.0001 }
            .sorted { $0.multiplier != $1.multiplier ? $0.multiplier > $1.multiplier : $0.type < $1.type }
    }

    /// Attack types the defender resists, most resisted first.
    public static func resistances(of defenderTypes: [String], battle: BattleTables) -> [TypeMultiplier] {
        multipliers(defenderTypes, battle: battle).filter { $0.multiplier < 0.9999 }
            .sorted { $0.multiplier != $1.multiplier ? $0.multiplier < $1.multiplier : $0.type < $1.type }
    }

    private static func multipliers(_ defenderTypes: [String], battle: BattleTables) -> [TypeMultiplier] {
        battle.typeOrder.map { TypeMultiplier(type: $0, multiplier: battle.effectiveness(of: $0, against: defenderTypes)) }
    }

    // MARK: - Names

    /// Matches a feed name ("Mega Charizard X", "Primal Kyogre", "Shadow Raikou", "Zacian (Crowned Sword)")
    /// to a gamemaster entry. PvPoke names megas "Charizard (Mega X)" and primals "Kyogre (Primal)".
    public static func resolve(_ name: String, lookup: GamemasterLookup) -> GMPokemon? {
        if let p = lookup.pokemon(named: name) { return p }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        for prefix in ["Mega", "Primal"] where trimmed.hasPrefix(prefix + " ") {
            let rest = String(trimmed.dropFirst(prefix.count + 1))
            var parts = rest.split(separator: " ").map(String.init)
            if parts.count > 1, let last = parts.last, ["X", "Y"].contains(last) {
                parts.removeLast()
                if let p = lookup.pokemon(named: "\(parts.joined(separator: " ")) (\(prefix) \(last))") { return p }
            }
            if let p = lookup.pokemon(named: "\(rest) (\(prefix))") { return p }
        }
        return nil
    }

    public static func isShadowEntry(_ p: GMPokemon) -> Bool {
        p.tags.contains("shadow") || p.speciesId.hasSuffix("_shadow")
    }

    public static func isMegaEntry(_ p: GMPokemon) -> Bool {
        p.tags.contains("mega") || p.speciesId.contains("_mega") || p.speciesId.contains("_primal")
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { seen.insert($0).inserted }
    }
}

extension GMPokemon {
    /// PvPoke's base stats as GameMath's `BaseStats`. Qualified, because inside this extension the bare
    /// name means PvPoke's own nested `GMPokemon.BaseStats`.
    var stats: GameMath.BaseStats {
        GameMath.BaseStats(attack: baseStats.atk, defense: baseStats.def, stamina: baseStats.hp)
    }
}
