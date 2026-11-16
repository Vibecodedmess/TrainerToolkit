import XCTest
@testable import Counters
import DataSources
import GameMath

/// Bundled data only; the expected best pair is recomputed by brute force, not remembered.
final class BestMovesTests: XCTestCase {
    private var gamemaster: Gamemaster!
    private var levels: LevelTables!
    private var battle: BattleTables!

    override func setUpWithError() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        gamemaster = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        levels = try LevelTables.bundled()
        battle = try BattleTables.bundled()
    }

    func testBestPairBeatsEveryOtherPair() throws {
        let species = gamemaster.pokemon.filter { $0.released && !CounterRanker.isShadowEntry($0) }.prefix(40)
        var checked = 0
        for p in species {
            guard let best = BestMoves.forSpecies(p, levels: levels, battle: battle) else { continue }
            let all = Set(p.fastMoves + p.chargedMoves + p.eliteMoves + p.legacyMoves)
            XCTAssertTrue(all.contains(best.fastMoveId), p.speciesName)
            if let charged = best.chargedMoveId { XCTAssertTrue(all.contains(charged), p.speciesName) }
            XCTAssertEqual(battle.move(best.fastMoveId)?.fast, true, p.speciesName)

            let base = BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
            let ivs = IVs(attack: 15, defense: 15, stamina: 15)
            let attacker = Combatant(base: base, ivs: ivs, level: PokemonLevel(40), types: p.realTypes)
            let target = Combatant(base: base, ivs: ivs, level: PokemonLevel(40), types: [])
            func dps(_ f: String, _ c: String?) -> Double {
                DamageCalculator.evaluate(attacker: attacker, fastMoveId: f, chargedMoveId: c, defender: target,
                                          weather: nil, levels: levels, battle: battle)?.dps ?? -1
            }
            let bestDPS = dps(best.fastMoveId, best.chargedMoveId)
            let fasts = all.filter { battle.move($0)?.fast == true }
            let chargeds = all.filter { battle.move($0)?.fast == false }
            for f in fasts {
                for c in chargeds { XCTAssertLessThanOrEqual(dps(f, c), bestDPS + 1e-9, "\(p.speciesName) \(f)+\(c)") }
            }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 10)
    }
}
