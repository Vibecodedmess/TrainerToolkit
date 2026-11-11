import XCTest
@testable import Counters
import DataSources
import GameMath

/// Uses the bundled data only. No remembered game values: expectations are computed from the
/// tables or from the ranking's own definition.
final class CounterRankerTests: XCTestCase {
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

    private func anyRegular() throws -> GMPokemon {
        try XCTUnwrap(gamemaster.pokemon.first { $0.released && !CounterRanker.isShadowEntry($0) && !CounterRanker.isMegaEntry($0) })
    }

    func testWeaknessesAndResistancesMatchTheTypeChart() throws {
        let types = try anyRegular().realTypes
        let weak = CounterRanker.weaknesses(of: types, battle: battle)
        let resist = CounterRanker.resistances(of: types, battle: battle)
        for w in weak {
            XCTAssertEqual(w.multiplier, battle.effectiveness(of: w.type, against: types), accuracy: 1e-12)
            XCTAssertGreaterThan(w.multiplier, 1)
        }
        for r in resist { XCTAssertLessThan(r.multiplier, 1) }
        XCTAssertEqual(weak.map(\.multiplier), weak.map(\.multiplier).sorted(by: >))
        XCTAssertEqual(resist.map(\.multiplier), resist.map(\.multiplier).sorted())
        // Every type is weak, resisted or neutral, and none is both.
        XCTAssertTrue(Set(weak.map(\.type)).isDisjoint(with: resist.map(\.type)))
    }

    func testGenericPoolRespectsOptions() {
        let noShadow = CounterRanker.genericCandidates(gamemaster, options: .init(includeShadow: false, includeMega: false))
        XCTAssertFalse(noShadow.isEmpty)
        XCTAssertFalse(noShadow.contains { $0.combatant.isShadow })
        XCTAssertFalse(noShadow.contains { c in lookup.pokemon(id: c.speciesId).map(CounterRanker.isMegaEntry) ?? false })
        XCTAssertEqual(Set(noShadow.map(\.id)).count, noShadow.count)
        let unreleased = Set(gamemaster.pokemon.filter { !$0.released }.map(\.speciesId))
        XCTAssertTrue(noShadow.allSatisfy { !unreleased.contains($0.speciesId) })

        let withShadow = CounterRanker.genericCandidates(gamemaster, options: .init(includeShadow: true))
        let shadows = withShadow.filter { $0.combatant.isShadow }
        XCTAssertFalse(shadows.isEmpty)
        XCTAssertTrue(shadows.allSatisfy { lookup.pokemon(id: $0.speciesId).map(CounterRanker.isShadowEntry) ?? false })

        let noSpecial = CounterRanker.genericCandidates(gamemaster, options: .init(includeSpecialMoves: false))
        for c in noSpecial {
            guard let p = lookup.pokemon(id: c.speciesId) else { continue }
            let special = Set(p.eliteMoves + p.legacyMoves)
            XCTAssertTrue(special.isDisjoint(with: c.fastMoveIds + c.chargedMoveIds), c.name)
        }
    }

    func testRankingIsSortedAndMatchesTheDamageCalculator() throws {
        let boss = try anyRegular()
        let defender = CounterRanker.defender(boss)
        let pool = CounterRanker.genericCandidates(gamemaster, options: .init())
        let ranked = CounterRanker.rank(pool, against: defender, weather: nil, levels: levels, battle: battle)
        XCTAssertGreaterThan(ranked.count, 10)
        XCTAssertEqual(ranked.first?.relativeDPS ?? 0, 1, accuracy: 1e-12)
        XCTAssertEqual(ranked.map(\.moveset.dps), ranked.map(\.moveset.dps).sorted(by: >))
        XCTAssertTrue(ranked.allSatisfy { $0.relativeDPS > 0 && $0.relativeDPS <= 1 })

        let top = try XCTUnwrap(ranked.first)
        let expected = DamageCalculator.bestMoveset(attacker: top.candidate.combatant, fastMoveIds: top.candidate.fastMoveIds,
                                                    chargedMoveIds: top.candidate.chargedMoveIds, defender: defender,
                                                    weather: nil, levels: levels, battle: battle)
        XCTAssertEqual(top.moveset, expected)

        let limited = CounterRanker.rank(pool, against: defender, weather: nil, levels: levels, battle: battle, limit: 6)
        XCTAssertEqual(limited.map(\.id), Array(ranked.prefix(6)).map(\.id))
    }

    /// Made-up fixture: two identical attackers except for their fast move's type. The one whose move
    /// type hits the defender harder (per the type chart) must rank first.
    func testSuperEffectiveMoveRanksAboveResistedMove() throws {
        let defenderTypes = try anyRegular().realTypes
        let fastMoves = battle.moves.filter(\.fast)
        func eff(_ m: BattleTables.PvEMove) -> Double { battle.effectiveness(of: m.type, against: defenderTypes) }
        let bestEff = try XCTUnwrap(fastMoves.map(eff).max())
        // Strongest-typed fast move with the most power; then a resisted move that is no better on power or speed.
        let strong = try XCTUnwrap(fastMoves.filter { eff($0) == bestEff }.max { $0.power < $1.power })
        let weakOptions = fastMoves.filter { eff($0) < 1 && $0.power <= strong.power && $0.durationMs >= strong.durationMs }
        try XCTSkipIf(bestEff <= 1 || strong.power < 3 || weakOptions.isEmpty, "No fair fixture pair in this data")
        let weak = weakOptions[0]

        let body = Combatant(base: BaseStats(attack: 200, defense: 150, stamina: 150), ivs: IVs(attack: 15, defense: 15, stamina: 15),
                             level: PokemonLevel(30), types: ["notatype"])
        let defender = Combatant(base: BaseStats(attack: 200, defense: 200, stamina: 200), ivs: IVs(attack: 15, defense: 15, stamina: 15),
                                 level: PokemonLevel(40), types: defenderTypes)
        let a = CounterCandidate(id: "a", speciesId: "a", name: "A", combatant: body, fastMoveIds: [weak.id], chargedMoveIds: [], isMine: true)
        let b = CounterCandidate(id: "b", speciesId: "b", name: "B", combatant: body, fastMoveIds: [strong.id], chargedMoveIds: [], isMine: true)
        let ranked = CounterRanker.rank([a, b], against: defender, weather: nil, levels: levels, battle: battle)
        XCTAssertEqual(ranked.map(\.id), ["b", "a"])
    }

    func testRankAgainstAllAveragesRelativeDPS() throws {
        let defenders = gamemaster.pokemon.filter { $0.released && !CounterRanker.isShadowEntry($0) }.prefix(3).map { CounterRanker.defender($0) }
        let pool = Array(CounterRanker.genericCandidates(gamemaster, options: .init()).prefix(40))
        let combined = CounterRanker.rankAgainstAll(pool, defenders: Array(defenders), weather: nil, levels: levels, battle: battle)
        XCTAssertEqual(combined.map(\.score), combined.map(\.score).sorted(by: >))
        let first = try XCTUnwrap(combined.first)
        var sum = 0.0
        for d in defenders {
            let r = CounterRanker.rank(pool, against: d, weather: nil, levels: levels, battle: battle)
            sum += r.first { $0.id == first.candidate.id }?.relativeDPS ?? 0
        }
        XCTAssertEqual(first.score, sum / Double(defenders.count), accuracy: 1e-9)
    }

    /// Mega and primal names are built from the data itself, so this doesn't depend on remembered names.
    func testResolveMegaAndPrimalFeedNames() {
        var checked = 0
        for p in gamemaster.pokemon where CounterRanker.isMegaEntry(p) {
            // "Charizard (Mega X)" -> "Mega Charizard X"; "Gyarados (Mega)" -> "Mega Gyarados".
            guard let open = p.speciesName.firstIndex(of: "("), let close = p.speciesName.lastIndex(of: ")") else { continue }
            let base = p.speciesName[..<open].trimmingCharacters(in: .whitespaces)
            let form = p.speciesName[p.speciesName.index(after: open)..<close].split(separator: " ").map(String.init)
            guard let prefix = form.first, ["Mega", "Primal"].contains(prefix), form.count <= 2 else { continue }
            let feedName = ([prefix, base] + form.dropFirst()).joined(separator: " ")
            XCTAssertEqual(CounterRanker.resolve(feedName, lookup: lookup)?.speciesName, p.speciesName, feedName)
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
    }

    func testResolveFindsPlainNames() throws {
        let p = try anyRegular()
        XCTAssertEqual(CounterRanker.resolve(p.speciesName, lookup: lookup)?.speciesName, p.speciesName)
        XCTAssertNil(CounterRanker.resolve("Not A Real Name", lookup: lookup))
    }
}
