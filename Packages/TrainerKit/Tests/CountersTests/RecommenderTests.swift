import XCTest
@testable import Counters
import DataSources
import GameMath

/// Bundled data, made-up levels, events, bonuses and dates only.
final class RecommenderTests: XCTestCase {
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

    private func team(level: Double, count: Int) -> [CounterCandidate] {
        Array(CounterRanker.genericCandidates(gamemaster, options: .init(level: PokemonLevel(level), includeShadow: false))
            .prefix(count))
    }

    private func defenders(_ count: Int) -> [Combatant] {
        gamemaster.pokemon.filter { $0.released && !CounterRanker.isShadowEntry($0) && !CounterRanker.isMegaEntry($0) }
            .prefix(count).map { CounterRanker.defender($0) }
    }

    /// Two released, regular species from different families that resolve back to themselves by name.
    private func twoSpecies() throws -> (GMPokemon, GMPokemon) {
        let regular = gamemaster.pokemon.filter {
            $0.released && !CounterRanker.isShadowEntry($0) && !CounterRanker.isMegaEntry($0)
                && CounterRanker.resolve($0.speciesName, lookup: lookup)?.dex == $0.dex
        }
        let a = try XCTUnwrap(regular.first)
        let b = try XCTUnwrap(regular.first { Recommender.familyKey($0) != Recommender.familyKey(a) && $0.dex != a.dex })
        return (a, b)
    }

    // MARK: - Power-ups

    func testNextTarget() {
        let max = PokemonLevel(50)
        XCTAssertEqual(Recommender.nextTarget(from: PokemonLevel(25), maxLevel: max)?.value, 40)
        XCTAssertEqual(Recommender.nextTarget(from: PokemonLevel(40), maxLevel: max)?.value, 45)
        XCTAssertEqual(Recommender.nextTarget(from: PokemonLevel(45.5), maxLevel: max)?.value, 50)
        XCTAssertNil(Recommender.nextTarget(from: PokemonLevel(50), maxLevel: max))
        XCTAssertNil(Recommender.nextTarget(from: PokemonLevel(40), maxLevel: PokemonLevel(40)))
    }

    func testEveryPickReallyClimbs() throws {
        let members = team(level: 20, count: 30)
        let foes = defenders(3)
        let picks = Recommender.powerUps(members, defenders: foes, weather: nil, tables: levels, battle: battle)
        XCTAssertFalse(picks.isEmpty, "30 counters at level 20 should give someone a reason to power up")
        for pick in picks {
            XCTAssertEqual(pick.target.value, 40)
            XCTAssertFalse(pick.joinsTeam.isEmpty && pick.becomesBest.isEmpty)
            let others = members.filter { $0.id != pick.candidate.id }
            for d in pick.joinsTeam + pick.becomesBest {
                let points = PowerUpValue.evaluate(pick.candidate, at: [PokemonLevel(20), pick.target], others: others,
                                                   against: foes[d], weather: nil, tables: levels, battle: battle)
                let after = try XCTUnwrap(points.last)
                XCTAssertEqual(after.level, pick.target)
                if pick.joinsTeam.contains(d) {
                    XCTAssertLessThanOrEqual(after.rank, 6)
                    if points.count == 2 { XCTAssertGreaterThan(points[0].rank, 6) }
                }
                if pick.becomesBest.contains(d) {
                    XCTAssertEqual(after.rank, 1)
                    if points.count == 2 { XCTAssertNotEqual(points[0].rank, 1) }
                }
            }
        }
        XCTAssertEqual(picks.map(\.score), picks.map(\.score).sorted(by: >))
    }

    func testNoPicksForSmallTeamsOrMaxLevel() {
        let foes = defenders(2)
        XCTAssertTrue(Recommender.powerUps(team(level: 20, count: 6), defenders: foes, weather: nil,
                                           tables: levels, battle: battle).isEmpty, "everyone is already in the best 6")
        XCTAssertTrue(Recommender.powerUps(team(level: levels.maxUpgradeLevel.value, count: 20), defenders: foes, weather: nil,
                                           tables: levels, battle: battle).isEmpty, "nobody can be powered up")
        XCTAssertTrue(Recommender.powerUps(team(level: 20, count: 20), defenders: [], weather: nil,
                                           tables: levels, battle: battle).isEmpty)
    }

    // MARK: - Events

    private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private func event(_ id: String, start: Date, end: Date, extra: [String: Any]) throws -> SDEvent {
        let json: [String: Any] = ["eventID": id, "name": "Made-up \(id)", "eventType": "event", "heading": "Event",
                                   "start": iso(start), "end": iso(end), "extraData": extra]
        return try JSONDecoder().decode(SDEvent.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testEventsForGoalsNewSpeciesAndBonuses() throws {
        let (a, b) = try twoSpecies()
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let day: TimeInterval = 24 * 3600
        let spotlightA: [String: Any] = ["spotlight": ["name": a.speciesName, "bonus": "Made-up bonus",
                                                       "list": [["name": a.speciesName]]]]
        let feed = [
            try event("live", start: now - day, end: now + day, extra: spotlightA),
            try event("soon", start: now + 3 * day, end: now + 3 * day + 3600,
                      extra: ["communityday": ["spawns": [["name": b.speciesName]], "bonuses": [["text": "Made-up bonus 2"]]]]),
            try event("later", start: now + 30 * day, end: now + 31 * day, extra: spotlightA),
            try event("over", start: now - 3 * day, end: now - 2 * day, extra: spotlightA),
        ]
        let picks = Recommender.events(EventCalendar.resolve(feed, now: now), now: now,
                                       goalSpeciesIds: [a.speciesId], ownedSpeciesIds: [b.speciesId], lookup: lookup)
        XCTAssertEqual(picks.map(\.id), ["live", "soon"], "no events past the horizon or already over; best first")
        let live = picks[0]
        XCTAssertEqual(live.forGoals, [a.speciesName])
        XCTAssertEqual(live.new, [a.speciesName])
        XCTAssertEqual(live.bonuses, ["Made-up bonus"])
        let soon = picks[1]
        XCTAssertTrue(soon.forGoals.isEmpty)
        XCTAssertTrue(soon.new.isEmpty, "already in the collection")
        XCTAssertEqual(soon.bonuses, ["Made-up bonus 2"])
    }

    func testEventsWithNothingForYouAreLeftOut() throws {
        let (a, _) = try twoSpecies()
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let feed = [try event("plain", start: now - 3600, end: now + 3600,
                              extra: ["communityday": ["spawns": [["name": a.speciesName]]]])]
        let picks = Recommender.events(EventCalendar.resolve(feed, now: now), now: now,
                                       goalSpeciesIds: [], ownedSpeciesIds: [a.speciesId], lookup: lookup)
        XCTAssertTrue(picks.isEmpty)
    }

    // MARK: - Raids

    private func boss(_ name: String, tier: String, shiny: Bool) throws -> SDRaidBoss {
        let json: [String: Any] = ["name": name, "tier": tier, "canBeShiny": shiny]
        return try JSONDecoder().decode(SDRaidBoss.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testRaidsEstimatedFirstWithCounters() throws {
        let (a, b) = try twoSpecies()
        let table = try RaidEstimate.Table.bundled()
        let estimatedLabel = "5-Star Raids", unestimatedLabel = "Shadow 3-Star Raids"
        try XCTSkipUnless(table.tier(forFeedTier: estimatedLabel)?.estimate == true
                          && table.tier(forFeedTier: unestimatedLabel)?.estimate == false,
                          "fixture labels must map to an estimated and an unestimated tier")
        let bosses = [try boss(b.speciesName, tier: unestimatedLabel, shiny: false),
                      try boss(a.speciesName, tier: estimatedLabel, shiny: true)]
        let picks = Recommender.raids(bosses, team: team(level: 30, count: 40), ownedSpeciesIds: [b.speciesId],
                                      table: table, weather: nil, lookup: lookup, levels: levels, battle: battle)
        XCTAssertEqual(picks.map(\.boss.name), [a.speciesName, b.speciesName])
        let first = picks[0], second = picks[1]
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(first.trainers), 1)
        XCTAssertEqual(first.topCounters.count, 3)
        XCTAssertTrue(first.isNew)
        XCTAssertTrue(first.canBeShiny)
        XCTAssertNil(second.trainers)
        XCTAssertNotNil(second.notEstimated)
        XCTAssertFalse(second.isNew)
    }

    func testRaidsWithoutATeamHaveNoEstimate() throws {
        let (a, _) = try twoSpecies()
        let picks = Recommender.raids([try boss(a.speciesName, tier: "5-Star Raids", shiny: false)], team: [],
                                      ownedSpeciesIds: [], table: try RaidEstimate.Table.bundled(), weather: nil,
                                      lookup: lookup, levels: levels, battle: battle)
        XCTAssertEqual(picks.count, 1)
        XCTAssertNil(picks[0].trainers)
        XCTAssertTrue(picks[0].topCounters.isEmpty)
    }
}
