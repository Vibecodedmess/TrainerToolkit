import XCTest
@testable import GameMath

final class BattleTablesTests: XCTestCase {
    private var battle: BattleTables!

    override func setUpWithError() throws {
        battle = try BattleTables.bundled()
    }

    func testShape() {
        XCTAssertEqual(battle.typeOrder.count, 18)
        XCTAssertEqual(Set(battle.typeChart.keys), Set(battle.typeOrder))
        XCTAssertTrue(battle.typeChart.values.allSatisfy { $0.count == 18 })
        XCTAssertFalse(battle.weatherBoosts.isEmpty)
        // Every boosted type is a real type.
        XCTAssertTrue(battle.weatherBoosts.values.joined().allSatisfy { battle.typeOrder.contains($0) })
        XCTAssertGreaterThan(battle.moves.count, 300)
        XCTAssertGreaterThan(battle.sameTypeAttackBonus, 1)
        XCTAssertGreaterThan(battle.weatherAttackBonus, 1)
    }

    /// Sanity checks that the extracted chart is oriented correctly (attacker rows, defender columns).
    func testTypeChartOrientation() {
        XCTAssertGreaterThan(battle.effectiveness(of: "fire", against: ["grass"]), 1)
        XCTAssertLessThan(battle.effectiveness(of: "fire", against: ["water"]), 1)
        XCTAssertGreaterThan(battle.effectiveness(of: "water", against: ["fire"]), 1)
        // Immunities are a very strong resistance in this game.
        XCTAssertLessThan(battle.effectiveness(of: "normal", against: ["ghost"]), 0.5)
        XCTAssertLessThan(battle.effectiveness(of: "electric", against: ["ground"]), 0.5)
        XCTAssertEqual(battle.effectiveness(of: "normal", against: ["normal"]), 1)
    }

    func testDualTypeMultipliesAndUnknownTypesAreNeutral() {
        let single = battle.effectiveness(of: "fire", against: ["bug"])
        let steel = battle.effectiveness(of: "fire", against: ["steel"])
        XCTAssertEqual(battle.effectiveness(of: "fire", against: ["bug", "steel"]), single * steel, accuracy: 1e-12)
        XCTAssertEqual(battle.effectiveness(of: "fire", against: ["notatype"]), 1)
        XCTAssertEqual(battle.effectiveness(of: "notatype", against: ["grass"]), 1)
        XCTAssertEqual(battle.effectiveness(of: "Fire", against: ["GRASS"]), battle.effectiveness(of: "fire", against: ["grass"]))
    }

    func testWeather() {
        for (weather, types) in battle.weatherBoosts {
            for type in types { XCTAssertTrue(battle.isBoosted(type, in: weather)) }
        }
        XCTAssertFalse(battle.isBoosted("fire", in: nil))
        XCTAssertFalse(battle.isBoosted("fire", in: "not-a-weather"))
    }

    func testMoveLookupAndSigns() throws {
        let fast = try XCTUnwrap(battle.move("VINE_WHIP"))
        XCTAssertTrue(fast.fast)
        XCTAssertGreaterThan(fast.energyDelta, 0)
        let charged = try XCTUnwrap(battle.move("SLUDGE_BOMB"))
        XCTAssertFalse(charged.fast)
        XCTAssertLessThan(charged.energyDelta, 0)
        XCTAssertTrue(battle.moves.filter(\.fast).allSatisfy { $0.energyDelta >= 0 })
        XCTAssertNil(battle.move("NOT_A_MOVE"))
    }
}

final class DamageCalculatorTests: XCTestCase {
    private var battle: BattleTables!
    private var levels: LevelTables!

    override func setUpWithError() throws {
        battle = try BattleTables.bundled()
        levels = try LevelTables.bundled()
    }

    func testDamageFormula() {
        // 0.5 x 100 x (203/100) x 1 = 101.5 -> 101 + 1
        XCTAssertEqual(DamageCalculator.damage(power: 100, attack: 203, defense: 100, multiplier: 1), 102)
        // x1.2 = 121.8 -> 121 + 1
        XCTAssertEqual(DamageCalculator.damage(power: 100, attack: 203, defense: 100, multiplier: 1.2), 122)
        // Zero-power moves still do 1 damage.
        XCTAssertEqual(DamageCalculator.damage(power: 0, attack: 203, defense: 100, multiplier: 1), 1)
    }

    func testMultiplierCombinesStabWeatherAndEffectiveness() throws {
        let move = try XCTUnwrap(battle.move("VINE_WHIP"))  // grass
        let neutral = DamageCalculator.multiplier(move: move, attackerTypes: ["normal"], defenderTypes: ["normal"], weather: nil, battle: battle)
        XCTAssertEqual(neutral, 1)
        let stab = DamageCalculator.multiplier(move: move, attackerTypes: ["grass"], defenderTypes: ["normal"], weather: nil, battle: battle)
        XCTAssertEqual(stab, battle.sameTypeAttackBonus, accuracy: 1e-12)
        let grassWeather = try XCTUnwrap(battle.weatherBoosts.first { $0.value.contains("grass") }?.key)
        let all = DamageCalculator.multiplier(move: move, attackerTypes: ["grass"], defenderTypes: ["water"], weather: grassWeather, battle: battle)
        XCTAssertEqual(all, battle.sameTypeAttackBonus * battle.weatherAttackBonus * battle.effectiveness(of: "grass", against: ["water"]), accuracy: 1e-12)
    }

    func testShadowHitsHarderAndTakesMore() throws {
        let base = BaseStats(attack: 200, defense: 150, stamina: 150)
        let normal = Combatant(base: base, ivs: .perfect, level: PokemonLevel(40), types: ["fire"])
        var shadow = normal
        shadow.isShadow = true
        let a = try XCTUnwrap(DamageCalculator.attackStat(normal, levels: levels, battle: battle))
        let sa = try XCTUnwrap(DamageCalculator.attackStat(shadow, levels: levels, battle: battle))
        XCTAssertEqual(sa / a, battle.shadowAttackMultiplier, accuracy: 1e-9)
        let d = try XCTUnwrap(DamageCalculator.defenseStat(normal, levels: levels, battle: battle))
        let sd = try XCTUnwrap(DamageCalculator.defenseStat(shadow, levels: levels, battle: battle))
        XCTAssertEqual(sd / d, battle.shadowDefenseMultiplier, accuracy: 1e-9)
    }

    func testCycleDPS() {
        func move(_ id: String, fast: Bool, ms: Int, energy: Int) -> BattleTables.PvEMove {
            let json = #"{"id":"\#(id)","fast":\#(fast),"type":"normal","power":10,"durationMs":\#(ms),"damageWindowStartMs":0,"energyDelta":\#(energy)}"#
            return try! JSONDecoder().decode(BattleTables.PvEMove.self, from: Data(json.utf8))
        }
        let fast = move("F", fast: true, ms: 1000, energy: 10)
        let charged = move("C", fast: false, ms: 2000, energy: -50)
        // 5 fast (50 dmg, 5 s) + 1 charged (100 dmg, 2 s) = 150 / 7 s
        XCTAssertEqual(DamageCalculator.cycleDPS(fast: fast, fastDamage: 10, charged: charged, chargedDamage: 100), 150.0 / 7, accuracy: 1e-9)
        // A weak charged move never lowers DPS below fast-move-only DPS.
        XCTAssertEqual(DamageCalculator.cycleDPS(fast: fast, fastDamage: 10, charged: charged, chargedDamage: 1), 10, accuracy: 1e-9)
        XCTAssertEqual(DamageCalculator.cycleDPS(fast: fast, fastDamage: 10, charged: nil, chargedDamage: 0), 10, accuracy: 1e-9)
        // 7 energy per fast move needs 8 fast moves for a 50-energy charge (rounded up).
        let slowFast = move("S", fast: true, ms: 1000, energy: 7)
        XCTAssertEqual(DamageCalculator.cycleDPS(fast: slowFast, fastDamage: 10, charged: charged, chargedDamage: 200), 280.0 / 10, accuracy: 1e-9)
    }

    func testBestMovesetPicksSuperEffectiveMoves() throws {
        let attacker = Combatant(base: BaseStats(attack: 200, defense: 150, stamina: 150), ivs: .perfect,
                                 level: PokemonLevel(40), types: ["grass", "poison"])
        let defender = Combatant(base: BaseStats(attack: 200, defense: 200, stamina: 200), ivs: .perfect,
                                 level: PokemonLevel(40), types: ["fairy"])
        // Against a Fairy defender, the Poison charged move (super effective) should beat the Grass one.
        let best = try XCTUnwrap(DamageCalculator.bestMoveset(
            attacker: attacker, fastMoveIds: ["VINE_WHIP"], chargedMoveIds: ["SEED_BOMB", "SLUDGE_BOMB"],
            defender: defender, weather: nil, levels: levels, battle: battle))
        XCTAssertEqual(best.chargedMoveId, "SLUDGE_BOMB")
        XCTAssertGreaterThan(best.dps, 0)
        XCTAssertNil(DamageCalculator.evaluate(attacker: attacker, fastMoveId: "NOT_A_MOVE", chargedMoveId: nil,
                                               defender: defender, weather: nil, levels: levels, battle: battle))
    }
}
