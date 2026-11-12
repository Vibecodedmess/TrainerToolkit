import Foundation
import GameMath

/// Finds the level and IVs that give a Pokémon's CP and HP, like an IV calculator.
///
/// Every half level from 1 to the Best Buddy maximum and every IV combination (0–15 each) is tried
/// with the app's own CP/HP formulas (CPCalculator, bundled PokeMiners tables). The next power-up's
/// stardust cost narrows the level; appraisal bar readings narrow the IVs.
public enum IVSolver {
    public struct Solution: Hashable, Sendable, Identifiable {
        public let level: PokemonLevel
        public let ivs: IVs
        /// Sum of |IV − bar reading| over the stats that had a reading (0 = exact match).
        public let distance: Int
        public var id: String { "\(level.halfSteps)-\(ivs.attack)-\(ivs.defense)-\(ivs.stamina)" }
    }

    public struct Hints: Hashable, Sendable {
        public var attack: Int?
        public var defense: Int?
        public var stamina: Int?
        public init(attack: Int? = nil, defense: Int? = nil, stamina: Int? = nil) {
            self.attack = attack
            self.defense = defense
            self.stamina = stamina
        }
        public var isEmpty: Bool { attack == nil && defense == nil && stamina == nil }
    }

    /// - Parameters:
    ///   - powerUpStardust: stardust shown on the POWER UP button (nil = unknown, or at max level).
    ///   - tolerance: how far an IV may be from its bar reading.
    /// - Returns: matching solutions, closest to the bar readings first, then by level.
    public static func solve(base: BaseStats, cp: Int, hp: Int?, powerUpStardust: Int?,
                             modifiers: CostModifiers, hints: Hints = Hints(), tolerance: Int = 1,
                             tables: LevelTables) -> [Solution] {
        let levels = PokemonLevel.all(from: PokemonLevel(1), through: tables.maxBestBuddyLevel).filter { level in
            guard let dust = powerUpStardust else { return true }
            guard level < tables.maxUpgradeLevel else { return false }
            return PowerUpCalculator.cost(from: level, to: level.next, modifiers: modifiers, tables: tables).stardust == dust
        }
        func allowed(_ value: Int, _ hint: Int?) -> Bool { hint.map { abs($0 - value) <= tolerance } ?? true }

        var result: [Solution] = []
        for level in levels {
            for s in IVs.range where allowed(s, hints.stamina) {
                if let hp, CPCalculator.hp(base: base, ivs: IVs(attack: 0, defense: 0, stamina: s), level: level, tables: tables) != hp {
                    continue
                }
                for a in IVs.range where allowed(a, hints.attack) {
                    for d in IVs.range where allowed(d, hints.defense) {
                        let ivs = IVs(attack: a, defense: d, stamina: s)
                        guard CPCalculator.cp(base: base, ivs: ivs, level: level, tables: tables) == cp else { continue }
                        let distance = abs(a - (hints.attack ?? a)) + abs(d - (hints.defense ?? d)) + abs(s - (hints.stamina ?? s))
                        result.append(Solution(level: level, ivs: ivs, distance: distance))
                    }
                }
            }
        }
        return result.sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.level != $1.level { return $0.level < $1.level }
            return ($0.ivs.attack, $0.ivs.defense, $0.ivs.stamina) > ($1.ivs.attack, $1.ivs.defense, $1.ivs.stamina)
        }
    }
}
