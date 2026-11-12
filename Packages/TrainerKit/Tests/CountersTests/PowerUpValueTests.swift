import XCTest
@testable import Counters
import DataSources
import GameMath

/// Bundled data and made-up IVs/levels only.
final class PowerUpValueTests: XCTestCase {
    private var gamemaster: Gamemaster!
    private var lookup: GamemasterLookup!
    private var levels: LevelTables!
    private var battle: BattleTables!

    override func setUpWithError() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        gamemaster = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        lookup = GamemasterLookup(gamemaster)
        levels = try LevelTables.bundled()
        battle = try BattleTables.bundled()
    }

    private func pool() -> [CounterCandidate] {
        CounterRanker.genericCandidates(gamemaster, options: .init(level: PokemonLevel(20), includeShadow: false))
    }

    func testComparisonLevels() {
        let max = PokemonLevel(50)
        XCTAssertEqual(PowerUpValue.comparisonLevels(from: PokemonLevel(25), maxLevel: max).map(\.value), [25, 40, 45, 50])
        XCTAssertEqual(PowerUpValue.comparisonLevels(from: PokemonLevel(41), maxLevel: max).map(\.value), [41, 45, 50])
        XCTAssertEqual(PowerUpValue.comparisonLevels(from: PokemonLevel(50), maxLevel: max).map(\.value), [50])
        XCTAssertEqual(PowerUpValue.comparisonLevels(from: PokemonLevel(30), maxLevel: PokemonLevel(40)).map(\.value), [30, 40])
    }

    func testHigherLevelNeverRanksWorseAndMatchesTheRanker() throws {
        let all = pool()
        let defender = CounterRanker.defender(try XCTUnwrap(gamemaster.pokemon.first { $0.released && !CounterRanker.isShadowEntry($0) }))
        let subject = try XCTUnwrap(all.dropFirst(5).first)
        let others = Array(all.prefix(30)).filter { $0.id != subject.id }
        let lv = PowerUpValue.comparisonLevels(from: PokemonLevel(20), maxLevel: levels.maxUpgradeLevel)
        let points = PowerUpValue.evaluate(subject, at: lv, others: others, against: defender, weather: nil, tables: levels, battle: battle)
        XCTAssertEqual(points.map(\.level), lv)
        for (a, b) in zip(points, points.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b.dps, a.dps)
            XCTAssertLessThanOrEqual(b.rank, a.rank)
            XCTAssertGreaterThanOrEqual(b.relativeToBest, a.relativeToBest - 1e-12)
        }
        // At its own level, the rank equals its place in the ranker's ordering of everyone.
        let first = try XCTUnwrap(points.first)
        let ranked = CounterRanker.rank(others + [subject], against: defender, weather: nil, levels: levels, battle: battle)
        let position = try XCTUnwrap(ranked.firstIndex { $0.id == subject.id })
        let tiesAbove = ranked.prefix(position).filter { $0.moveset.dps == first.dps }.count
        XCTAssertEqual(first.rank, position + 1 - tiesAbove)
        XCTAssertTrue(points.allSatisfy { $0.relativeToBest > 0 && $0.relativeToBest <= 1 && $0.ofCount == ranked.count })
    }

    func testAloneItIsTheBest() throws {
        let subject = try XCTUnwrap(pool().first)
        let defender = CounterRanker.defender(try XCTUnwrap(gamemaster.pokemon.first { $0.released }))
        let points = PowerUpValue.evaluate(subject, at: [PokemonLevel(20), PokemonLevel(40)], others: [], against: defender,
                                           weather: nil, tables: levels, battle: battle)
        XCTAssertEqual(points.map(\.rank), [1, 1])
        XCTAssertEqual(points.map(\.relativeToBest), [1, 1])
    }

    func testEvolvedCandidateKeepsIVsAndUsesRegularMoves() throws {
        let root = try XCTUnwrap(gamemaster.pokemon.first { $0.released && !($0.family?.evolutions ?? []).isEmpty && !CounterRanker.isShadowEntry($0) })
        let target = try XCTUnwrap(lookup.pokemon(id: try XCTUnwrap(root.family?.evolutions?.first)))
        let subject = try XCTUnwrap(CounterRanker.genericCandidates(gamemaster, options: .init(level: PokemonLevel(27), ivs: IVs(attack: 3, defense: 9, stamina: 12)))
            .first { $0.speciesId == root.speciesId })
        let evolved = try XCTUnwrap(PowerUpValue.evolvedCandidate(from: subject, into: target))
        XCTAssertEqual(evolved.speciesId, target.speciesId)
        XCTAssertEqual(evolved.combatant.ivs, subject.combatant.ivs)
        XCTAssertEqual(evolved.combatant.level, subject.combatant.level)
        XCTAssertEqual(evolved.combatant.types, target.realTypes)
        let special = Set(target.eliteMoves + target.legacyMoves)
        XCTAssertTrue(special.isDisjoint(with: evolved.fastMoveIds + evolved.chargedMoveIds))
    }
}
