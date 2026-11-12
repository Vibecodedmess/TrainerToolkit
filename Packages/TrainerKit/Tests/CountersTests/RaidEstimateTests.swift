import XCTest
@testable import Counters
import DataSources
import GameMath

/// The tier numbers are a cited community table; tests check its shape and the math, not the values.
final class RaidEstimateTests: XCTestCase {
    private var gamemaster: Gamemaster!
    private var levels: LevelTables!
    private var battle: BattleTables!
    private var table: RaidEstimate.Table!

    override func setUpWithError() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        gamemaster = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        levels = try LevelTables.bundled()
        battle = try BattleTables.bundled()
        table = try RaidEstimate.Table.bundled()
    }

    func testTableShapeAndSource() {
        XCTAssertFalse(table.source.pages.isEmpty)
        XCTAssertFalse(table.source.license.isEmpty)
        XCTAssertEqual(Set(table.tiers.map(\.id)).count, table.tiers.count)
        for t in table.tiers {
            XCTAssertGreaterThan(t.bossHP, 0, t.id)
            XCTAssertGreaterThan(t.cpMultiplier, 0, t.id)
            XCTAssertGreaterThan(t.timeLimitSeconds, 0, t.id)
            if !t.estimate { XCTAssertNotNil(t.note, "\(t.id) needs a reason why it isn't estimated") }
        }
    }

    func testFeedTierLabels() {
        let cases: [(String, String?)] = [
            ("1-Star Raids", "one_star"), ("3-Star Raids", "three_star"), ("5-Star Raids", "five_star"),
            ("Mega Raids", "mega"), ("Mega Legendary Raids", "mega_legendary"), ("Primal Raids", "primal"),
            ("Shadow 1-Star Raids", "shadow_one_star"), ("Shadow 3-Star Raids", "shadow_three_star"),
            ("Shadow 5-Star Raids", "shadow_five_star"), ("Shadow Legendary Raids", "shadow_five_star"),
            ("Super Mega Raids", "super_mega"), ("Elite Raids", "elite"), ("Ultra Beast Raids", "ultra_beast"),
            ("Something New", nil),
        ]
        for (label, id) in cases {
            XCTAssertEqual(RaidEstimate.tierId(forFeedTier: label), id, label)
            if let id { XCTAssertNotNil(table.tier(id), "\(id) missing from raid-tiers.json") }
        }
    }

    private func boss() throws -> GMPokemon {
        try XCTUnwrap(gamemaster.pokemon.first { $0.released && !CounterRanker.isShadowEntry($0) && !CounterRanker.isMegaEntry($0) })
    }

    /// With a made-up tier whose multiplier equals the level-40 CP multiplier, the DPS must match
    /// DamageCalculator against a level-40, 15-IV defender: same defence, same formula.
    func testDPSMatchesDamageCalculatorAtTheSameDefence() throws {
        let b = try boss()
        let base = BaseStats(attack: b.baseStats.atk, defense: b.baseStats.def, stamina: b.baseStats.hp)
        let cpm40 = try XCTUnwrap(CPCalculator.cpMultiplier(at: PokemonLevel(40), tables: levels))
        let tier = RaidEstimate.Tier(id: "test", name: "Test", bossHP: 10_000, cpMultiplier: cpm40, timeLimitSeconds: 300,
                                     estimate: true, note: nil)
        let defender = CounterRanker.defender(b)
        for c in CounterRanker.genericCandidates(gamemaster, options: .init()).prefix(25) {
            let expected = DamageCalculator.bestMoveset(attacker: c.combatant, fastMoveIds: c.fastMoveIds, chargedMoveIds: c.chargedMoveIds,
                                                        defender: defender, weather: nil, levels: levels, battle: battle)?.dps
            let actual = RaidEstimate.dps(c, bossBase: base, bossTypes: b.realTypes, tier: tier, weather: nil, levels: levels, battle: battle)
            if let expected, let actual {
                XCTAssertEqual(actual, expected, accuracy: 1e-9, c.name)
            }
        }
    }

    func testEstimateMath() throws {
        let b = try boss()
        let base = BaseStats(attack: b.baseStats.atk, defense: b.baseStats.def, stamina: b.baseStats.hp)
        let party = Array(CounterRanker.genericCandidates(gamemaster, options: .init()).prefix(6))
        func tier(hp: Int, seconds: Int = 300, estimate: Bool = true) -> RaidEstimate.Tier {
            RaidEstimate.Tier(id: "t", name: "T", bossHP: hp, cpMultiplier: 0.7, timeLimitSeconds: seconds, estimate: estimate, note: nil)
        }
        let small = try XCTUnwrap(RaidEstimate.estimate(party: party, bossBase: base, bossTypes: b.realTypes, tier: tier(hp: 1_000),
                                                        weather: nil, levels: levels, battle: battle))
        let big = try XCTUnwrap(RaidEstimate.estimate(party: party, bossBase: base, bossTypes: b.realTypes, tier: tier(hp: 1_000_000),
                                                      weather: nil, levels: levels, battle: battle))
        XCTAssertGreaterThanOrEqual(small.trainers, 1)
        XCTAssertGreaterThan(big.trainers, small.trainers)
        XCTAssertEqual(big.damagePerTrainer, big.partyDPS * 300, accuracy: 1e-6)
        XCTAssertEqual(big.trainers, Int((1_000_000 / big.damagePerTrainer).rounded(.up)))
        // Less time, more trainers.
        let short = try XCTUnwrap(RaidEstimate.estimate(party: party, bossBase: base, bossTypes: b.realTypes,
                                                        tier: tier(hp: 1_000_000, seconds: 100), weather: nil, levels: levels, battle: battle))
        XCTAssertGreaterThan(short.trainers, big.trainers)
        // Not estimated tiers, and empty parties, give nil.
        XCTAssertNil(RaidEstimate.estimate(party: party, bossBase: base, bossTypes: b.realTypes, tier: tier(hp: 1_000, estimate: false),
                                           weather: nil, levels: levels, battle: battle))
        XCTAssertNil(RaidEstimate.estimate(party: [], bossBase: base, bossTypes: b.realTypes, tier: tier(hp: 1_000),
                                           weather: nil, levels: levels, battle: battle))
    }
}
