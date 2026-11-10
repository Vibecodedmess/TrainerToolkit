import Foundation

/// CP and HP from base stats, IVs and level.
///
/// Formulas (community-documented, e.g. Bulbapedia "Combat Power" / GamePress; the game master
/// only lists whole-level multipliers):
/// - CP = floor((Atk + IVatk) * sqrt(Def + IVdef) * sqrt(Sta + IVsta) * CPM^2 / 10), minimum 10
/// - HP = floor((Sta + IVsta) * CPM), minimum 10
/// - Half-level CPM: sqrt((CPM(L)^2 + CPM(L+1)^2) / 2)
/// The CP formula and whole-level CPMs are cross-checked in tests against PvPoke's
/// `level25CP` value for every species.
public enum CPCalculator {
    public static func cpMultiplier(at level: PokemonLevel, tables: LevelTables) -> Double? {
        let whole = level.wholeLevel
        guard whole >= 1, whole <= tables.cpMultiplier.count else { return nil }
        let low = tables.cpMultiplier[whole - 1]
        if level.isWhole { return low }
        guard whole < tables.cpMultiplier.count else { return nil }
        let high = tables.cpMultiplier[whole]
        return ((low * low + high * high) / 2).squareRoot()
    }

    public static func cp(base: BaseStats, ivs: IVs, level: PokemonLevel, tables: LevelTables) -> Int? {
        guard let cpm = cpMultiplier(at: level, tables: tables) else { return nil }
        let attack = Double(base.attack + ivs.attack)
        let defense = Double(base.defense + ivs.defense)
        let stamina = Double(base.stamina + ivs.stamina)
        let raw = attack * defense.squareRoot() * stamina.squareRoot() * (cpm * cpm) / 10
        return max(10, Int(raw.rounded(.down)))
    }

    public static func hp(base: BaseStats, ivs: IVs, level: PokemonLevel, tables: LevelTables) -> Int? {
        guard let cpm = cpMultiplier(at: level, tables: tables) else { return nil }
        return max(10, Int((Double(base.stamina + ivs.stamina) * cpm).rounded(.down)))
    }

    /// All levels (1 ... maxLevel) at which a Pokémon with these stats and IVs has exactly `cp`.
    /// Usually one level; low levels can share a CP, so the result can have several.
    public static func levels(matchingCP cp: Int, base: BaseStats, ivs: IVs,
                              maxLevel: PokemonLevel, tables: LevelTables) -> [PokemonLevel] {
        PokemonLevel.all(from: PokemonLevel(1), through: maxLevel).filter {
            self.cp(base: base, ivs: ivs, level: $0, tables: tables) == cp
        }
    }
}
