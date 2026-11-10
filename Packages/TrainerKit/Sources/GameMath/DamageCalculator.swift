import Foundation

/// One side of a raid/gym battle.
public struct Combatant: Hashable, Sendable {
    public var base: BaseStats
    public var ivs: IVs
    public var level: PokemonLevel
    public var types: [String]
    public var isShadow: Bool

    public init(base: BaseStats, ivs: IVs, level: PokemonLevel, types: [String], isShadow: Bool = false) {
        self.base = base
        self.ivs = ivs
        self.level = level
        self.types = types
        self.isShadow = isShadow
    }
}

/// PvE damage and DPS estimates.
///
/// Damage per hit (community-documented PvE formula, e.g. GamePress "Damage Calculation"):
///   damage = floor(0.5 x Power x (Attack / Defense) x Multipliers) + 1
///   Attack  = (base Atk + IV) x CPM (x shadow attack multiplier)
///   Defense = (base Def + IV) x CPM (x shadow defense multiplier)
///   Multipliers = same-type bonus x weather bonus x type effectiveness
/// All multipliers come from the game master (BattleTables). The formula itself is not in the game
/// master; it is the standard community model.
///
/// DPS here is a simple "cycle" estimate: use fast moves until there is energy for one charged move,
/// then fire it; repeat. It ignores dodging, energy from damage taken, and travel/retarget time,
/// so it is useful for ranking, not as an exact battle simulation.
public enum DamageCalculator {
    public static func attackStat(_ c: Combatant, levels: LevelTables, battle: BattleTables) -> Double? {
        guard let cpm = CPCalculator.cpMultiplier(at: c.level, tables: levels) else { return nil }
        return Double(c.base.attack + c.ivs.attack) * cpm * (c.isShadow ? battle.shadowAttackMultiplier : 1)
    }

    public static func defenseStat(_ c: Combatant, levels: LevelTables, battle: BattleTables) -> Double? {
        guard let cpm = CPCalculator.cpMultiplier(at: c.level, tables: levels) else { return nil }
        return Double(c.base.defense + c.ivs.defense) * cpm * (c.isShadow ? battle.shadowDefenseMultiplier : 1)
    }

    /// Total multiplier for one move: same-type bonus, weather bonus and type effectiveness.
    public static func multiplier(move: BattleTables.PvEMove, attackerTypes: [String], defenderTypes: [String],
                                  weather: String?, battle: BattleTables) -> Double {
        var m = battle.effectiveness(of: move.type, against: defenderTypes)
        if attackerTypes.map({ $0.lowercased() }).contains(move.type.lowercased()) { m *= battle.sameTypeAttackBonus }
        if battle.isBoosted(move.type, in: weather) { m *= battle.weatherAttackBonus }
        return m
    }

    public static func damage(power: Double, attack: Double, defense: Double, multiplier: Double) -> Int {
        guard defense > 0 else { return 1 }
        return Int((0.5 * power * (attack / defense) * multiplier).rounded(.down)) + 1
    }

    public static func damage(move: BattleTables.PvEMove, attacker: Combatant, defender: Combatant,
                              weather: String?, levels: LevelTables, battle: BattleTables) -> Int? {
        guard let attack = attackStat(attacker, levels: levels, battle: battle),
              let defense = defenseStat(defender, levels: levels, battle: battle) else { return nil }
        let m = multiplier(move: move, attackerTypes: attacker.types, defenderTypes: defender.types,
                           weather: weather, battle: battle)
        return damage(power: move.power, attack: attack, defense: defense, multiplier: m)
    }

    /// Damage per second of the fast/charged cycle (or of fast moves alone, if that is higher).
    public static func cycleDPS(fast: BattleTables.PvEMove, fastDamage: Int,
                                charged: BattleTables.PvEMove?, chargedDamage: Int) -> Double {
        let fastSeconds = Double(fast.durationMs) / 1000
        guard fastSeconds > 0 else { return 0 }
        let fastOnly = Double(fastDamage) / fastSeconds
        guard let charged, fast.energyDelta > 0, charged.energyDelta < 0 else { return fastOnly }
        let cost = Double(-charged.energyDelta)
        let fastMovesPerCharge = (cost / Double(fast.energyDelta)).rounded(.up)
        let cycleSeconds = fastMovesPerCharge * fastSeconds + Double(charged.durationMs) / 1000
        guard cycleSeconds > 0 else { return fastOnly }
        let cycleDamage = fastMovesPerCharge * Double(fastDamage) + Double(chargedDamage)
        return max(cycleDamage / cycleSeconds, fastOnly)
    }

    public struct MovesetResult: Hashable, Sendable {
        public let fastMoveId: String
        public let chargedMoveId: String?
        public let fastDamage: Int
        public let chargedDamage: Int
        public let dps: Double
    }

    /// DPS of one attacker with one moveset against a defender. Nil if a move has no PvE data.
    public static func evaluate(attacker: Combatant, fastMoveId: String, chargedMoveId: String?,
                                defender: Combatant, weather: String?,
                                levels: LevelTables, battle: BattleTables) -> MovesetResult? {
        guard let fast = battle.move(fastMoveId),
              let fastDamage = damage(move: fast, attacker: attacker, defender: defender,
                                      weather: weather, levels: levels, battle: battle) else { return nil }
        var charged: BattleTables.PvEMove?
        var chargedDamage = 0
        if let id = chargedMoveId {
            guard let move = battle.move(id),
                  let d = damage(move: move, attacker: attacker, defender: defender,
                                 weather: weather, levels: levels, battle: battle) else { return nil }
            charged = move
            chargedDamage = d
        }
        let dps = cycleDPS(fast: fast, fastDamage: fastDamage, charged: charged, chargedDamage: chargedDamage)
        return MovesetResult(fastMoveId: fastMoveId, chargedMoveId: chargedMoveId,
                             fastDamage: fastDamage, chargedDamage: chargedDamage, dps: dps)
    }

    /// Best moveset (highest DPS) from the given move lists.
    public static func bestMoveset(attacker: Combatant, fastMoveIds: [String], chargedMoveIds: [String],
                                   defender: Combatant, weather: String?,
                                   levels: LevelTables, battle: BattleTables) -> MovesetResult? {
        var best: MovesetResult?
        for fast in fastMoveIds {
            for charged in chargedMoveIds.isEmpty ? [nil] : chargedMoveIds.map({ Optional($0) }) {
                guard let r = evaluate(attacker: attacker, fastMoveId: fast, chargedMoveId: charged,
                                       defender: defender, weather: weather, levels: levels, battle: battle) else { continue }
                if r.dps > (best?.dps ?? -1) { best = r }
            }
        }
        return best
    }
}
