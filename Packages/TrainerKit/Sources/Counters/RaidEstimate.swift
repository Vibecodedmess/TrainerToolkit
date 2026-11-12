import Foundation
import GameMath

/// A rough "how many trainers" estimate for a raid.
///
/// Raid boss HP, stat multiplier and time limit per tier are held by the game's servers. They come
/// from a cited community table (Resources/raid-tiers.json, Bulbapedia, `TODO: verify`), shown as
/// unverified in the app. The estimate is a best case: the party's average DPS for the whole time
/// limit, with no fainting, dodging, relobbying, friendship or party bonuses.
public enum RaidEstimate {
    public struct Tier: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let bossHP: Int
        /// The boss's Attack/Defense multiplier (it replaces a level's CP multiplier).
        public let cpMultiplier: Double
        public let timeLimitSeconds: Int
        /// False when the tier has a mechanic the estimate doesn't model (enrage, shields).
        public let estimate: Bool
        public let note: String?
    }

    public struct Source: Decodable, Sendable, Hashable {
        public let name: String
        public let pages: [String]
        public let retrieved: String
        public let license: String
        public let note: String
    }

    public struct Table: Decodable, Sendable {
        public let source: Source
        public let tiers: [Tier]

        public static func bundled() throws -> Table {
            guard let url = Bundle.module.url(forResource: "raid-tiers", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(Table.self, from: Data(contentsOf: url))
        }

        public func tier(_ id: String) -> Tier? { tiers.first { $0.id == id } }

        /// The tier for a raid feed label such as "5-Star Raids", "Mega Raids" or "Shadow 3-Star Raids".
        public func tier(forFeedTier label: String) -> Tier? {
            RaidEstimate.tierId(forFeedTier: label).flatMap { tier($0) }
        }
    }

    /// Maps a feed tier label to a tier id. Nil for labels it doesn't recognise.
    public static func tierId(forFeedTier label: String) -> String? {
        let t = label.lowercased()
        let stars = t.first(where: { $0.isNumber }).flatMap { Int(String($0)) }
        if t.contains("shadow") {
            if t.contains("legendary") { return "shadow_five_star" }
            switch stars {
            case 1: return "shadow_one_star"
            case 3: return "shadow_three_star"
            case 5: return "shadow_five_star"
            default: return nil
            }
        }
        if t.contains("super") && t.contains("mega") { return "super_mega" }
        if t.contains("primal") { return "primal" }
        if t.contains("mega") { return t.contains("legendary") ? "mega_legendary" : "mega" }
        if t.contains("elite") { return "elite" }
        if t.contains("ultra beast") || t.contains("wormhole") { return "ultra_beast" }
        if t.contains("legendary") { return "five_star" }
        switch stars {
        case 1: return "one_star"
        case 2: return "two_star"
        case 3: return "three_star"
        case 4: return "four_star"
        case 5: return "five_star"
        default: return nil
        }
    }

    /// Best-moveset DPS against a raid boss with the tier's stat multiplier (boss IVs count as 15).
    public static func dps(_ c: CounterCandidate, bossBase: BaseStats, bossTypes: [String], tier: Tier,
                           weather: String?, levels: LevelTables, battle: BattleTables) -> Double? {
        guard let attack = DamageCalculator.attackStat(c.combatant, levels: levels, battle: battle) else { return nil }
        let defense = Double(bossBase.defense + 15) * tier.cpMultiplier
        var best: Double?
        for fastId in c.fastMoveIds {
            guard let fast = battle.move(fastId) else { continue }
            let fastDamage = damage(fast, attack: attack, defense: defense, attacker: c, bossTypes: bossTypes, weather: weather, battle: battle)
            let chargedOptions: [String?] = c.chargedMoveIds.isEmpty ? [nil] : c.chargedMoveIds.map { Optional($0) }
            for chargedId in chargedOptions {
                var charged: BattleTables.PvEMove?
                var chargedDamage = 0
                if let id = chargedId {
                    guard let move = battle.move(id) else { continue }
                    charged = move
                    chargedDamage = damage(move, attack: attack, defense: defense, attacker: c, bossTypes: bossTypes,
                                           weather: weather, battle: battle)
                }
                let value = DamageCalculator.cycleDPS(fast: fast, fastDamage: fastDamage, charged: charged, chargedDamage: chargedDamage)
                if value > (best ?? -1) { best = value }
            }
        }
        return best
    }

    private static func damage(_ move: BattleTables.PvEMove, attack: Double, defense: Double, attacker: CounterCandidate,
                               bossTypes: [String], weather: String?, battle: BattleTables) -> Int {
        let m = DamageCalculator.multiplier(move: move, attackerTypes: attacker.combatant.types, defenderTypes: bossTypes,
                                            weather: weather, battle: battle)
        return DamageCalculator.damage(power: move.power, attack: attack, defense: defense, multiplier: m)
    }

    public struct Result: Hashable, Sendable {
        /// Average DPS of the party members that have usable moves.
        public let partyDPS: Double
        /// What one trainer deals in the whole time limit at that DPS.
        public let damagePerTrainer: Double
        /// Boss HP ÷ damage per trainer, rounded up (at least 1).
        public let trainers: Int
        public let counted: Int
    }

    /// Best-case trainers needed, if every trainer brings this party. Nil if the tier isn't
    /// estimated or no party member has usable moves.
    public static func estimate(party: [CounterCandidate], bossBase: BaseStats, bossTypes: [String], tier: Tier,
                                weather: String?, levels: LevelTables, battle: BattleTables) -> Result? {
        guard tier.estimate, tier.timeLimitSeconds > 0 else { return nil }
        let values = party.compactMap { dps($0, bossBase: bossBase, bossTypes: bossTypes, tier: tier, weather: weather,
                                            levels: levels, battle: battle) }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        let average = values.reduce(0, +) / Double(values.count)
        let perTrainer = average * Double(tier.timeLimitSeconds)
        let trainers = max(1, Int((Double(tier.bossHP) / perTrainer).rounded(.up)))
        return Result(partyDPS: average, damagePerTrainer: perTrainer, trainers: trainers, counted: values.count)
    }
}
