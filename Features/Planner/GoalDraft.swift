import Foundation
import GameMath
import DataSources

/// Shared access to the bundled level tables.
enum PlannerMath {
    static let tables: LevelTables? = try? LevelTables.bundled()
}

/// Editable copy of a power-up goal, with all derived numbers. Saved into `PowerUpGoal`.
struct GoalDraft: Equatable {
    var speciesId: String?
    var speciesName = ""
    var types: [String] = []
    var base: BaseStats?
    var ivs = IVs(attack: 10, defense: 10, stamina: 10)
    var current = PokemonLevel(20)
    var target = PokemonLevel(40)
    var isShadow = false
    var isPurified = false
    var isLucky = false
    var isBestBuddy = false
    var candyOwned = 0
    var xlCandyOwned = 0
    var candyIncome: Double = 0
    var xlCandyIncome: Double = 0
    var incomeIsPerWeek = false

    var modifiers: CostModifiers {
        CostModifiers(isShadow: isShadow, isPurified: isPurified, isLucky: isLucky)
    }

    var isComplete: Bool { speciesId != nil && base != nil }

    func maxLevel(_ tables: LevelTables) -> PokemonLevel {
        isBestBuddy ? tables.maxBestBuddyLevel : tables.maxUpgradeLevel
    }

    func cost(_ tables: LevelTables) -> PowerUpCost {
        PowerUpCalculator.cost(from: current, to: target, modifiers: modifiers, tables: tables)
    }

    func cp(at level: PokemonLevel, _ tables: LevelTables) -> Int? {
        guard let base else { return nil }
        return CPCalculator.cp(base: base, ivs: ivs, level: level, tables: tables)
    }

    var dailyIncome: GoalEstimator.DailyIncome {
        let divisor = incomeIsPerWeek ? 7.0 : 1.0
        return .init(candy: candyIncome / divisor, xlCandy: xlCandyIncome / divisor)
    }

    var owned: GoalEstimator.Resources {
        .init(candy: candyOwned, xlCandy: xlCandyOwned)
    }

    /// Keeps levels inside the allowed range after a Best Buddy toggle or level change.
    mutating func clampLevels(_ tables: LevelTables) {
        let maxLevel = maxLevel(tables)
        current = min(max(current, PokemonLevel(1)), maxLevel)
        target = min(max(target, PokemonLevel(1)), maxLevel)
    }

    mutating func select(_ pokemon: GMPokemon) {
        speciesId = pokemon.speciesId
        speciesName = pokemon.speciesName
        types = pokemon.realTypes
        base = pokemon.stats
        // PvPoke lists shadow forms separately; picking one switches the shadow option on.
        if pokemon.tags.contains("shadow") { isShadow = true; isPurified = false; isLucky = false }
    }
}

extension GoalDraft {
    init(goal: PowerUpGoal, types: [String]) {
        speciesId = goal.speciesId
        speciesName = goal.speciesName
        self.types = types
        base = BaseStats(attack: goal.baseAttack, defense: goal.baseDefense, stamina: goal.baseStamina)
        ivs = IVs(attack: goal.ivAttack, defense: goal.ivDefense, stamina: goal.ivStamina)
        current = PokemonLevel(halfSteps: goal.currentLevelHalfSteps)
        target = PokemonLevel(halfSteps: goal.targetLevelHalfSteps)
        isShadow = goal.isShadow
        isPurified = goal.isPurified
        isLucky = goal.isLucky
        isBestBuddy = goal.isBestBuddy
        candyOwned = goal.candyOwned
        xlCandyOwned = goal.xlCandyOwned
        candyIncome = goal.candyIncome
        xlCandyIncome = goal.xlCandyIncome
        incomeIsPerWeek = goal.incomeIsPerWeek
    }

    /// Copies the draft into an existing goal, or creates a new one. Nil if no Pokémon is picked.
    func apply(to goal: PowerUpGoal?) -> PowerUpGoal? {
        guard let speciesId, let base else { return nil }
        let model = goal ?? PowerUpGoal(
            speciesId: speciesId, speciesName: speciesName,
            baseAttack: base.attack, baseDefense: base.defense, baseStamina: base.stamina,
            ivAttack: 0, ivDefense: 0, ivStamina: 0, currentLevelHalfSteps: 2, targetLevelHalfSteps: 2,
            isShadow: false, isPurified: false, isLucky: false, isBestBuddy: false,
            candyOwned: 0, xlCandyOwned: 0, candyIncome: 0, xlCandyIncome: 0, incomeIsPerWeek: false)
        model.speciesId = speciesId
        model.speciesName = speciesName
        model.baseAttack = base.attack
        model.baseDefense = base.defense
        model.baseStamina = base.stamina
        model.ivAttack = ivs.attack
        model.ivDefense = ivs.defense
        model.ivStamina = ivs.stamina
        model.currentLevelHalfSteps = current.halfSteps
        model.targetLevelHalfSteps = target.halfSteps
        model.isShadow = isShadow
        model.isPurified = isPurified
        model.isLucky = isLucky
        model.isBestBuddy = isBestBuddy
        model.candyOwned = candyOwned
        model.xlCandyOwned = xlCandyOwned
        model.candyIncome = candyIncome
        model.xlCandyIncome = xlCandyIncome
        model.incomeIsPerWeek = incomeIsPerWeek
        return model
    }
}

extension Gamemaster {
    /// Pokémon that can be powered up: released, not Mega/Primal forms. Sorted by Pokédex number.
    var powerUpCandidates: [GMPokemon] {
        pokemon
            .filter { $0.released && !$0.tags.contains("mega") && !$0.speciesId.contains("_mega") && !$0.speciesId.contains("_primal") }
            .sorted { ($0.dex, $0.speciesName) < ($1.dex, $1.speciesName) }
    }

    func types(forSpecies id: String) -> [String] {
        pokemon.first { $0.speciesId == id }?.realTypes ?? []
    }
}

extension GMPokemon {
    /// PvPoke's base stats as GameMath's `BaseStats`. Qualified, because inside this extension the bare
    /// name means PvPoke's own nested `GMPokemon.BaseStats`.
    var stats: GameMath.BaseStats {
        GameMath.BaseStats(attack: baseStats.atk, defense: baseStats.def, stamina: baseStats.hp)
    }
}
