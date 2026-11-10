import XCTest
@testable import GameMath
import DataSources

final class LevelTablesTests: XCTestCase {
    func testBundledTablesLoadAndHaveExpectedShape() throws {
        let t = try LevelTables.bundled()
        XCTAssertFalse(t.source.commit.isEmpty)
        XCTAssertGreaterThanOrEqual(t.cpMultiplier.count, t.maxNormalUpgradeLevel + t.bestBuddyExtraLevels)
        XCTAssertEqual(t.upgradesPerLevel, 2)
        // Power-ups exist from level 1 up to (max - 0.5): one stardust entry per whole level below max.
        XCTAssertEqual(t.stardustCost.count, t.maxNormalUpgradeLevel - 1)
        XCTAssertEqual(t.xlCandyCost.count, t.maxNormalUpgradeLevel - t.xlCandyMinPokemonLevel)
        // CP multiplier never decreases with level.
        XCTAssertEqual(t.cpMultiplier, t.cpMultiplier.sorted())
        // Regular candy is replaced by XL Candy from the XL level on.
        XCTAssertTrue(t.candyCost.dropFirst(t.xlCandyMinPokemonLevel - 1).allSatisfy { $0 == 0 })
    }
}

final class CPCalculatorTests: XCTestCase {
    private var tables: LevelTables!

    override func setUpWithError() throws {
        tables = try LevelTables.bundled()
    }

    func testWholeLevelMultiplierComesFromTable() {
        XCTAssertEqual(CPCalculator.cpMultiplier(at: PokemonLevel(1), tables: tables), tables.cpMultiplier[0])
        XCTAssertEqual(CPCalculator.cpMultiplier(at: PokemonLevel(40), tables: tables), tables.cpMultiplier[39])
    }

    func testHalfLevelMultiplierIsBetweenNeighbours() throws {
        for whole in 1..<51 {
            let half = try XCTUnwrap(CPCalculator.cpMultiplier(at: PokemonLevel(Double(whole) + 0.5), tables: tables))
            let low = tables.cpMultiplier[whole - 1], high = tables.cpMultiplier[whole]
            XCTAssertGreaterThanOrEqual(half, low)
            XCTAssertLessThanOrEqual(half, high)
            XCTAssertEqual(half * half, (low * low + high * high) / 2, accuracy: 1e-12)
        }
    }

    func testOutOfRangeLevelsReturnNil() {
        XCTAssertNil(CPCalculator.cpMultiplier(at: PokemonLevel(0.5), tables: tables))
        XCTAssertNil(CPCalculator.cpMultiplier(at: PokemonLevel(Double(tables.cpMultiplier.count + 1)), tables: tables))
    }

    func testMinimumCPAndHPAreTen() throws {
        let tiny = BaseStats(attack: 1, defense: 1, stamina: 1)
        XCTAssertEqual(CPCalculator.cp(base: tiny, ivs: .zero, level: PokemonLevel(1), tables: tables), 10)
        XCTAssertEqual(CPCalculator.hp(base: tiny, ivs: .zero, level: PokemonLevel(1), tables: tables), 10)
    }

    func testCPRisesWithLevelAndIVs() throws {
        let base = BaseStats(attack: 200, defense: 150, stamina: 180)
        let low = try XCTUnwrap(CPCalculator.cp(base: base, ivs: .zero, level: PokemonLevel(20), tables: tables))
        let higherLevel = try XCTUnwrap(CPCalculator.cp(base: base, ivs: .zero, level: PokemonLevel(20.5), tables: tables))
        let higherIVs = try XCTUnwrap(CPCalculator.cp(base: base, ivs: .perfect, level: PokemonLevel(20), tables: tables))
        XCTAssertGreaterThan(higherLevel, low)
        XCTAssertGreaterThan(higherIVs, low)
    }

    func testLevelFinderRoundTrips() throws {
        let base = BaseStats(attack: 190, defense: 160, stamina: 170)
        let ivs = IVs(attack: 12, defense: 7, stamina: 15)
        for level in [PokemonLevel(15), PokemonLevel(27.5), PokemonLevel(40), PokemonLevel(51)] {
            let cp = try XCTUnwrap(CPCalculator.cp(base: base, ivs: ivs, level: level, tables: tables))
            let found = CPCalculator.levels(matchingCP: cp, base: base, ivs: ivs, maxLevel: tables.maxBestBuddyLevel, tables: tables)
            XCTAssertTrue(found.contains(level), "level \(level) not found for CP \(cp): \(found)")
        }
        XCTAssertTrue(CPCalculator.levels(matchingCP: 999_999, base: base, ivs: ivs, maxLevel: tables.maxBestBuddyLevel, tables: tables).isEmpty)
    }

    // MARK: - Cross-checks against PvPoke's independently computed values

    private func gamemaster() throws -> Gamemaster {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        let data = try Data(contentsOf: dir.appendingPathComponent("gamemaster.json"))
        return try JSONDecoder().decode(Gamemaster.self, from: data)
    }

    private func base(_ p: GMPokemon) -> BaseStats {
        BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
    }

    /// PvPoke lists `level25CP` (CP at level 25 with 0/0/0 IVs) for many species. Megas are skipped:
    /// PvPoke's numbers for them are clearly not computed from the mega stats.
    func testCPMatchesPvPokeLevel25CP() throws {
        let entries = try gamemaster().pokemon.filter { $0.level25CP != nil && !$0.speciesId.contains("_mega") }
        XCTAssertGreaterThan(entries.count, 300)
        var mismatches: [String] = []
        for p in entries {
            let cp = CPCalculator.cp(base: base(p), ivs: .zero, level: PokemonLevel(25), tables: tables)
            if cp != p.level25CP { mismatches.append("\(p.speciesId): \(cp ?? -1) vs \(p.level25CP!)") }
        }
        // A handful of PvPoke values are stale after stat changes (e.g. Hisuian Electrode on 2026-11-10).
        XCTAssertLessThanOrEqual(Double(mismatches.count) / Double(entries.count), 0.01, mismatches.joined(separator: "; "))
    }

    /// PvPoke's rank-1 league IV sets (level, atk, def, sta) must never exceed the league CP cap.
    /// This exercises half levels and IVs.
    func testPvPokeLeagueIVsStayUnderCap() throws {
        let caps = ["cp500": 500, "cp1500": 1500, "cp2500": 2500]
        var checked = 0
        var over: [String] = []
        for p in try gamemaster().pokemon {
            for (key, cap) in caps {
                guard let v = p.defaultIVs?[key], v.count == 4 else { continue }
                let ivs = IVs(attack: Int(v[1]), defense: Int(v[2]), stamina: Int(v[3]))
                guard let cp = CPCalculator.cp(base: base(p), ivs: ivs, level: PokemonLevel(v[0]), tables: tables) else { continue }
                checked += 1
                if cp > cap { over.append("\(p.speciesId) \(key): \(cp)") }
            }
        }
        XCTAssertGreaterThan(checked, 1000)
        XCTAssertTrue(over.isEmpty, over.prefix(10).joined(separator: "; "))
    }
}

final class PowerUpCalculatorTests: XCTestCase {
    private var tables: LevelTables!

    override func setUpWithError() throws {
        tables = try LevelTables.bundled()
    }

    private func cost(_ from: Double, _ to: Double, _ mods: CostModifiers = .none) -> PowerUpCost {
        PowerUpCalculator.cost(from: PokemonLevel(from), to: PokemonLevel(to), modifiers: mods, tables: tables)
    }

    func testOneWholeLevelIsTwoPowerUpsAtThatLevelsPrice() {
        let c = cost(1, 2)
        XCTAssertEqual(c.powerUps, 2)
        XCTAssertEqual(c.stardust, tables.stardustCost[0] * 2)
        XCTAssertEqual(c.candy, tables.candyCost[0] * 2)
        XCTAssertEqual(c.xlCandy, 0)
    }

    func testHalfLevelStartUsesItsWholeLevelPrice() {
        let c = cost(20.5, 21)
        XCTAssertEqual(c.powerUps, 1)
        XCTAssertEqual(c.stardust, tables.stardustCost[19])
        XCTAssertEqual(c.candy, tables.candyCost[19])
    }

    func testXLCandyFromLevel40() {
        let c = cost(40, 41)
        XCTAssertEqual(c.candy, 0)
        XCTAssertEqual(c.xlCandy, tables.xlCandyCost[0] * 2)
        XCTAssertEqual(c.stardust, tables.stardustCost[39] * 2)

        let crossing = cost(39, 41)
        XCTAssertEqual(crossing.candy, tables.candyCost[38] * 2)
        XCTAssertEqual(crossing.xlCandy, tables.xlCandyCost[0] * 2)
    }

    func testFullRangeEqualsSumOfTables() {
        let c = cost(1, 50)
        XCTAssertEqual(c.powerUps, 98)
        XCTAssertEqual(c.stardust, tables.stardustCost.reduce(0, +) * 2)
        XCTAssertEqual(c.candy, tables.candyCost.prefix(49).reduce(0, +) * 2)
        XCTAssertEqual(c.xlCandy, tables.xlCandyCost.reduce(0, +) * 2)
    }

    func testNothingToDoWhenTargetIsNotHigher() {
        XCTAssertEqual(cost(30, 30), .zero)
        XCTAssertEqual(cost(30, 20), .zero)
    }

    func testBestBuddyLevelsAreFree() {
        XCTAssertEqual(cost(45, 51), cost(45, 50))
    }

    func testShadowCostsMoreAndRoundsUp() {
        let normal = cost(1, 1.5)
        let shadow = cost(1, 1.5, CostModifiers(isShadow: true))
        XCTAssertEqual(shadow.stardust, PowerUpCalculator.scaled(normal.stardust, by: tables.shadowStardustMultiplier))
        XCTAssertGreaterThan(shadow.stardust, normal.stardust)
        // 1 Candy x 1.2 rounds up to 2 (rounding direction: TODO verify in game).
        XCTAssertEqual(normal.candy, 1)
        XCTAssertEqual(shadow.candy, 2)
    }

    func testExactProductsAreNotRoundedUpByFloatingPointNoise() {
        // 1300 x 1.2 = 1560 exactly, even though the Double product is 1560.0000000000002.
        XCTAssertEqual(PowerUpCalculator.scaled(1300, by: 1.2), 1560)
        XCTAssertEqual(PowerUpCalculator.scaled(200, by: 0.9), 180)
        XCTAssertEqual(PowerUpCalculator.scaled(0, by: 1.2), 0)
    }

    func testPurifiedCostsLess() {
        let normal = cost(10, 30)
        let purified = cost(10, 30, CostModifiers(isPurified: true))
        XCTAssertLessThan(purified.stardust, normal.stardust)
        XCTAssertLessThanOrEqual(purified.candy, normal.candy)
    }

    func testLuckyHalvesStardustOnly() {
        let normal = cost(20, 40)
        let lucky = cost(20, 40, CostModifiers(isLucky: true))
        XCTAssertEqual(lucky.candy, normal.candy)
        let expected = (20...39).reduce(0) { sum, level in
            sum + PowerUpCalculator.scaled(tables.stardustCost[level - 1], by: tables.luckyStardustDiscount) * 2
        }
        XCTAssertEqual(lucky.stardust, expected)
        XCTAssertLessThan(lucky.stardust, normal.stardust)
    }
}

final class GoalEstimatorTests: XCTestCase {
    private let cost = PowerUpCost(stardust: 100_000, candy: 100, xlCandy: 40, powerUps: 10)

    func testAlreadyAffordable() {
        let days = GoalEstimator.daysNeeded(cost: cost, have: .init(candy: 150, xlCandy: 40), income: .init())
        XCTAssertEqual(days, 0)
        XCTAssertEqual(GoalEstimator.progress(cost: cost, have: .init(candy: 150, xlCandy: 40)), 1)
    }

    func testSlowestResourceDecides() {
        // Candy: 60 missing at 10/day = 6 days. XL: 30 missing at 2/day = 15 days.
        let days = GoalEstimator.daysNeeded(cost: cost, have: .init(candy: 40, xlCandy: 10), income: .init(candy: 10, xlCandy: 2))
        XCTAssertEqual(days, 15)
    }

    func testRoundsUpPartialDays() {
        let days = GoalEstimator.daysNeeded(cost: cost, have: .init(candy: 99, xlCandy: 40), income: .init(candy: 3))
        XCTAssertEqual(days, 1)
    }

    func testNeverWithoutIncome() {
        XCTAssertNil(GoalEstimator.daysNeeded(cost: cost, have: .init(), income: .init(candy: 5, xlCandy: 0)))
    }

    func testStardustOnlyCountedWhenGiven() {
        let have = GoalEstimator.Resources(candy: 100, xlCandy: 40, stardust: 50_000)
        XCTAssertEqual(GoalEstimator.daysNeeded(cost: cost, have: have, income: .init()), 0, "no stardust income given: ignored")
        XCTAssertEqual(GoalEstimator.daysNeeded(cost: cost, have: have, income: .init(stardust: 10_000)), 5)
    }

    func testProgress() {
        XCTAssertEqual(GoalEstimator.progress(cost: cost, have: .init(candy: 70, xlCandy: 0)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GoalEstimator.progress(cost: .zero, have: .init()), 1)
    }
}
