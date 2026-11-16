import Foundation
import DataSources
import GameMath

/// A species' best raid/gym moveset in general: the fast + charged pair with the highest damage per
/// second against a neutral target (no type effectiveness, no weather), with the PvE move stats from
/// the game master. Elite TM and legacy moves count, since a trainer may have them.
///
/// The target is the species itself without types: its defence only scales every moveset's damage
/// by the same factor, so it doesn't change which pair is best (bar rounding).
public enum BestMoves {
    public struct Result: Hashable, Sendable {
        public let fastMoveId: String
        /// Nil when no charged move has PvE data.
        public let chargedMoveId: String?
    }

    public static func forSpecies(_ p: GMPokemon, levels: LevelTables, battle: BattleTables) -> Result? {
        let fast = unique(p.fastMoves + p.eliteMoves + p.legacyMoves).filter { battle.move($0)?.fast == true }
        let charged = unique(p.chargedMoves + p.eliteMoves + p.legacyMoves).filter { battle.move($0)?.fast == false }
        guard !fast.isEmpty else { return nil }
        let base = BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
        let ivs = IVs(attack: 15, defense: 15, stamina: 15)
        let attacker = Combatant(base: base, ivs: ivs, level: CounterRanker.standInDefenderLevel, types: p.realTypes,
                                 isShadow: CounterRanker.isShadowEntry(p))
        let target = Combatant(base: base, ivs: ivs, level: CounterRanker.standInDefenderLevel, types: [])
        guard let best = DamageCalculator.bestMoveset(attacker: attacker, fastMoveIds: fast, chargedMoveIds: charged,
                                                      defender: target, weather: nil, levels: levels, battle: battle)
        else { return nil }
        return Result(fastMoveId: best.fastMoveId, chargedMoveId: best.chargedMoveId)
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
