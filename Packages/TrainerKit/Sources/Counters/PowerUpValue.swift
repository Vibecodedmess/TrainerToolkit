import Foundation
import DataSources
import GameMath

/// "Is this power-up worth it?": one Pokémon's raid strength at several levels, compared with the
/// trainer's other counters (kept at their current levels).
public enum PowerUpValue {
    public struct Point: Hashable, Sendable, Identifiable {
        public let level: PokemonLevel
        /// Best-moveset DPS against the defender (stand-in defender, so only for comparing).
        public let dps: Double
        /// 1 = best of all counters, including the others.
        public let rank: Int
        /// The subject plus the others that have usable moves.
        public let ofCount: Int
        /// DPS divided by the best DPS among the subject (at this level) and the others. 0…1.
        public let relativeToBest: Double
        public var id: Int { level.halfSteps }
    }

    /// - Parameters:
    ///   - subject: the Pokémon to power up; its level is replaced by each of `levels`.
    ///   - others: the trainer's other counters, at their own levels.
    /// - Returns: one point per level for which the subject has usable moves.
    public static func evaluate(_ subject: CounterCandidate, at levels: [PokemonLevel], others: [CounterCandidate],
                                against defender: Combatant, weather: String?,
                                tables: LevelTables, battle: BattleTables) -> [Point] {
        let otherDPS: [Double] = others.compactMap {
            DamageCalculator.bestMoveset(attacker: $0.combatant, fastMoveIds: $0.fastMoveIds, chargedMoveIds: $0.chargedMoveIds,
                                         defender: defender, weather: weather, levels: tables, battle: battle)?.dps
        }.filter { $0 > 0 }
        let bestOther = otherDPS.max() ?? 0

        return levels.compactMap { level in
            var combatant = subject.combatant
            combatant.level = level
            guard let best = DamageCalculator.bestMoveset(attacker: combatant, fastMoveIds: subject.fastMoveIds,
                                                          chargedMoveIds: subject.chargedMoveIds, defender: defender,
                                                          weather: weather, levels: tables, battle: battle),
                  best.dps > 0 else { return nil }
            let rank = 1 + otherDPS.filter { $0 > best.dps }.count
            let top = max(best.dps, bestOther)
            return Point(level: level, dps: best.dps, rank: rank, ofCount: otherDPS.count + 1,
                         relativeToBest: top > 0 ? best.dps / top : 0)
        }
    }

    /// Levels worth comparing: the current level, then 40, 45 and 50 when higher, up to `maxLevel`.
    public static func comparisonLevels(from current: PokemonLevel, maxLevel: PokemonLevel) -> [PokemonLevel] {
        var result = [current]
        for whole in [40.0, 45.0, 50.0] {
            let level = PokemonLevel(whole)
            if level > current && level <= maxLevel { result.append(level) }
        }
        return result
    }

    /// The evolved Pokémon as a counter: same IVs, level and shadow status, with its regular moves
    /// (an evolved Pokémon gets random moves, so Elite TM / legacy moves are left out).
    public static func evolvedCandidate(from subject: CounterCandidate, into target: GMPokemon) -> CounterCandidate? {
        let special = Set(target.eliteMoves + target.legacyMoves)
        let fast = target.fastMoves.filter { !special.contains($0) }
        let charged = target.chargedMoves.filter { !special.contains($0) }
        guard !fast.isEmpty else { return nil }
        let base = BaseStats(attack: target.baseStats.atk, defense: target.baseStats.def, stamina: target.baseStats.hp)
        let combatant = Combatant(base: base, ivs: subject.combatant.ivs, level: subject.combatant.level,
                                  types: target.realTypes, isShadow: subject.combatant.isShadow)
        return CounterCandidate(id: subject.id + "->" + target.speciesId, speciesId: target.speciesId, name: target.speciesName,
                                combatant: combatant, fastMoveIds: fast, chargedMoveIds: charged, isMine: subject.isMine)
    }
}
