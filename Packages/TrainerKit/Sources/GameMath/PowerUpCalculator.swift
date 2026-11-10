import Foundation

public struct CostModifiers: Hashable, Codable, Sendable {
    public var isShadow: Bool
    public var isPurified: Bool
    public var isLucky: Bool

    public init(isShadow: Bool = false, isPurified: Bool = false, isLucky: Bool = false) {
        self.isShadow = isShadow
        self.isPurified = isPurified
        self.isLucky = isLucky
    }

    public static let none = CostModifiers()
}

public struct PowerUpCost: Hashable, Sendable {
    public var stardust: Int
    public var candy: Int
    public var xlCandy: Int
    public var powerUps: Int

    public init(stardust: Int = 0, candy: Int = 0, xlCandy: Int = 0, powerUps: Int = 0) {
        self.stardust = stardust
        self.candy = candy
        self.xlCandy = xlCandy
        self.powerUps = powerUps
    }

    public static let zero = PowerUpCost()
}

/// Stardust, Candy and XL Candy needed to power up between two levels.
///
/// Each power-up at whole level L (from L or from L+0.5) costs `stardustCost[L-1]`,
/// `candyCost[L-1]` and, from level 40, `xlCandyCost[L-40]` (tables from the game master).
/// Shadow / purified / lucky multipliers come from the game master too.
///
/// TODO: verify. The game master gives the multipliers but not how fractional results are rounded
/// (e.g. 1 Candy x 1.2 for a shadow, or 17 XL x 1.2 = 20.4). This rounds UP each power-up.
/// It also assumes a lucky purified Pokémon gets both stardust discounts, multiplied together.
public enum PowerUpCalculator {
    public static func cost(from start: PokemonLevel, to target: PokemonLevel,
                            modifiers: CostModifiers = .none, tables: LevelTables) -> PowerUpCost {
        // Levels above the normal maximum come from the Best Buddy boost and cost nothing.
        let end = min(target, tables.maxUpgradeLevel)
        guard start < end else { return .zero }

        let dustMultiplier = statusStardustMultiplier(modifiers, tables) * (modifiers.isLucky ? tables.luckyStardustDiscount : 1)
        let candyMultiplier = statusCandyMultiplier(modifiers, tables)

        var total = PowerUpCost.zero
        var level = start
        while level < end {
            let whole = level.wholeLevel
            let index = whole - 1
            guard index >= 0, index < tables.stardustCost.count else { break }
            let candy = index < tables.candyCost.count ? tables.candyCost[index] : 0
            let xlIndex = whole - tables.xlCandyMinPokemonLevel
            let xl = (xlIndex >= 0 && xlIndex < tables.xlCandyCost.count) ? tables.xlCandyCost[xlIndex] : 0

            total.stardust += scaled(tables.stardustCost[index], by: dustMultiplier)
            total.candy += scaled(candy, by: candyMultiplier)
            total.xlCandy += scaled(xl, by: candyMultiplier)
            total.powerUps += 1
            level = level.next
        }
        return total
    }

    static func statusStardustMultiplier(_ m: CostModifiers, _ t: LevelTables) -> Double {
        if m.isShadow { return t.shadowStardustMultiplier }
        if m.isPurified { return t.purifiedStardustMultiplier }
        return 1
    }

    static func statusCandyMultiplier(_ m: CostModifiers, _ t: LevelTables) -> Double {
        if m.isShadow { return t.shadowCandyMultiplier }
        if m.isPurified { return t.purifiedCandyMultiplier }
        return 1
    }

    /// value x multiplier, rounded up (TODO: verify rounding, see above). The small epsilon keeps
    /// exact results like 1300 x 1.2 = 1560.0000000000002 from rounding up to 1561.
    static func scaled(_ value: Int, by multiplier: Double) -> Int {
        guard value > 0, multiplier != 1 else { return value }
        return Int((Double(value) * multiplier - 1e-9).rounded(.up))
    }
}

/// "How long until I can afford this?" from the trainer's own income estimates.
public enum GoalEstimator {
    public struct Resources: Hashable, Sendable {
        public var candy: Int
        public var xlCandy: Int
        public var stardust: Int?

        public init(candy: Int = 0, xlCandy: Int = 0, stardust: Int? = nil) {
            self.candy = candy
            self.xlCandy = xlCandy
            self.stardust = stardust
        }
    }

    public struct DailyIncome: Hashable, Sendable {
        public var candy: Double
        public var xlCandy: Double
        public var stardust: Double?

        public init(candy: Double = 0, xlCandy: Double = 0, stardust: Double? = nil) {
            self.candy = candy
            self.xlCandy = xlCandy
            self.stardust = stardust
        }
    }

    /// Days until every needed resource is covered. 0 = affordable now.
    /// nil = something is still missing and its income is 0, so it never finishes.
    /// Stardust is only counted when both a stardust amount and an income are given.
    public static func daysNeeded(cost: PowerUpCost, have: Resources, income: DailyIncome) -> Int? {
        var days = 0
        func account(needed: Int, owned: Int, perDay: Double) -> Bool {
            let missing = needed - owned
            guard missing > 0 else { return true }
            guard perDay > 0 else { return false }
            days = max(days, Int((Double(missing) / perDay).rounded(.up)))
            return true
        }
        guard account(needed: cost.candy, owned: have.candy, perDay: income.candy),
              account(needed: cost.xlCandy, owned: have.xlCandy, perDay: income.xlCandy) else { return nil }
        if let dust = have.stardust, let dustPerDay = income.stardust {
            guard account(needed: cost.stardust, owned: dust, perDay: dustPerDay) else { return nil }
        }
        return days
    }

    /// Fraction (0...1) of the needed Candy + XL Candy already owned, for progress bars.
    public static func progress(cost: PowerUpCost, have: Resources) -> Double {
        let needed = cost.candy + cost.xlCandy
        guard needed > 0 else { return 1 }
        let owned = min(have.candy, cost.candy) + min(have.xlCandy, cost.xlCandy)
        return Double(owned) / Double(needed)
    }
}
