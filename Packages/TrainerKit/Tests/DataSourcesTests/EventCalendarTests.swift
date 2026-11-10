import XCTest
@testable import DataSources

final class EventCalendarTests: XCTestCase {
    private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func event(_ id: String, type: String = "event", start: String?, end: String?) -> SDEvent {
        let json: [String: Any?] = ["eventID": id, "name": id.capitalized, "eventType": type, "heading": "H",
                                    "start": start, "end": end, "extraData": nil]
        let data = try! JSONSerialization.data(withJSONObject: json.mapValues { $0 ?? NSNull() })
        return try! JSONDecoder().decode(SDEvent.self, from: data)
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    func testStatus() {
        let now = date("2026-11-21T12:00:00Z")
        XCTAssertEqual(EventCalendar.status(start: nil, end: nil, now: now), .undated)
        XCTAssertEqual(EventCalendar.status(start: date("2026-11-21T13:00:00Z"), end: nil, now: now), .upcoming)
        XCTAssertEqual(EventCalendar.status(start: date("2026-11-21T11:00:00Z"), end: date("2026-11-21T13:00:00Z"), now: now), .live)
        XCTAssertEqual(EventCalendar.status(start: date("2026-11-21T09:00:00Z"), end: date("2026-11-21T12:00:00Z"), now: now), .ended)
        XCTAssertEqual(EventCalendar.status(start: date("2026-11-20T09:00:00Z"), end: nil, now: now), .live, "no end = still running")
    }

    func testLocalEventHappensAtLocalWallClockInEachZone() throws {
        // Community Day 14:00-17:00 local time.
        let cd = event("cd", type: "community-day", start: "2026-11-21T14:00:00.000", end: "2026-11-21T17:00:00.000")
        // 13:30 UTC = 14:30 in Amsterdam (live) but 22:30 in Tokyo (ended).
        let now = date("2026-11-21T13:30:00Z")
        let inAmsterdam = try XCTUnwrap(EventCalendar.resolve([cd], now: now, timeZone: amsterdam).first)
        let inTokyo = try XCTUnwrap(EventCalendar.resolve([cd], now: now, timeZone: tokyo).first)
        XCTAssertEqual(inAmsterdam.status, .live)
        XCTAssertEqual(inTokyo.status, .ended)
        XCTAssertFalse(inAmsterdam.isGlobalTime)
    }

    func testGlobalEventIsSameInstantEverywhere() throws {
        let global = event("g", start: "2027-02-18T16:00:00.000Z", end: "2027-02-19T08:00:00.000Z")
        let a = try XCTUnwrap(EventCalendar.resolve([global], timeZone: amsterdam).first)
        let t = try XCTUnwrap(EventCalendar.resolve([global], timeZone: tokyo).first)
        XCTAssertEqual(a.start, t.start)
        XCTAssertTrue(a.isGlobalTime)
    }

    func testDisplayOrder() {
        let now = date("2026-11-21T12:00:00Z")
        let utc = TimeZone(identifier: "UTC")!
        let events = [
            event("ended", start: "2026-11-20T10:00:00Z", end: "2026-11-20T12:00:00Z"),
            event("later", start: "2026-11-25T10:00:00Z", end: "2026-11-25T12:00:00Z"),
            event("tba", start: nil, end: nil),
            event("soon", start: "2026-11-22T10:00:00Z", end: "2026-11-22T12:00:00Z"),
            event("livelong", start: "2026-11-01T10:00:00Z", end: "2026-12-01T12:00:00Z"),
            event("liveshort", start: "2026-11-21T10:00:00Z", end: "2026-11-21T13:00:00Z"),
        ]
        let sorted = EventCalendar.sortedForDisplay(EventCalendar.resolve(events, now: now, timeZone: utc))
        XCTAssertEqual(sorted.map(\.id), ["liveshort", "livelong", "soon", "later", "tba", "ended"])
    }

    func testNextCommunityDay() {
        let now = date("2026-11-21T12:00:00Z")
        let utc = TimeZone(identifier: "UTC")!
        let events = [
            event("oldcd", type: "community-day", start: "2026-10-01T14:00:00Z", end: "2026-10-01T17:00:00Z"),
            event("nextcd", type: "community-day", start: "2026-12-05T14:00:00Z", end: "2026-12-05T17:00:00Z"),
            event("latercd", type: "community-day", start: "2027-01-05T14:00:00Z", end: "2027-01-05T17:00:00Z"),
            event("other", start: "2026-11-22T14:00:00Z", end: "2026-11-22T17:00:00Z"),
        ]
        XCTAssertEqual(EventCalendar.nextCommunityDay(in: EventCalendar.resolve(events, now: now, timeZone: utc))?.id, "nextcd")
    }
}

final class EventExtrasTests: XCTestCase {
    func testCommunityDayExtras() throws {
        let json = """
        {"communityday":{
          "spawns":[{"name":"Testmon","image":"x"}],
          "bonuses":[{"text":"Increased Spawns","image":"x"},{"text":"2x <b>Catch</b> Candy","image":"x"}],
          "bonusDisclaimers":["* Some bonuses last until 9 p.m."],
          "shinies":[{"name":"Testmon","image":"x"},{"name":"Testevo","image":"x"}],
          "specialresearch":[{"name":"Field Notes (1/2)","step":1,
             "tasks":[{"text":"Catch 3 Testmon","reward":{"text":"Poké Ball <span>×15</span>","image":"x"}}],
             "rewards":[{"text":"×2000","image":"x"}]}]},
         "generic":{"hasSpawns":true,"hasFieldResearchTasks":false}}
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let extras = EventExtras(value)
        XCTAssertEqual(extras.spawns, ["Testmon"])
        XCTAssertEqual(extras.shinies, ["Testmon", "Testevo"])
        XCTAssertEqual(extras.bonuses, ["Increased Spawns", "2x Catch Candy"])
        XCTAssertEqual(extras.bonusDisclaimers.count, 1)
        XCTAssertEqual(extras.specialResearch.first?.step, 1)
        XCTAssertEqual(extras.specialResearch.first?.tasks.first?.reward, "Poké Ball ×15")
        XCTAssertEqual(extras.specialResearch.first?.rewards, ["×2000"])
        XCTAssertEqual(extras.hasSpawns, true)
        XCTAssertEqual(extras.hasFieldResearchTasks, false)
    }

    func testRaidAndSpotlightExtras() throws {
        let json = """
        {"raidbattles":{"bosses":[{"name":"Mega Testmon","canBeShiny":true}],"shinies":[{"name":"Testmon"}]},
         "spotlight":{"name":"A","bonus":"2× Catch Candy","list":[{"name":"A"},{"name":"B"}]}}
        """
        let extras = EventExtras(try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)))
        XCTAssertEqual(extras.raidBosses.map(\.name), ["Mega Testmon"])
        XCTAssertEqual(extras.raidBosses.first?.canBeShiny, true)
        XCTAssertEqual(extras.shinies, ["Testmon"])
        XCTAssertEqual(extras.featured, ["A", "B"])
        XCTAssertEqual(extras.spotlightBonus, "2× Catch Candy")
    }

    func testMissingExtraDataIsEmpty() {
        XCTAssertTrue(EventExtras(nil).isEmpty)
        XCTAssertTrue(EventExtras(.null).isEmpty)
    }

    func testPlainText() {
        XCTAssertEqual(EventExtras.plainText("<span>Power up</span>  Steel&amp;Fairy"), "Power up Steel&Fairy")
    }

    func testBundledEventsParseWithoutCrashing() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        let events = try JSONDecoder().decode([SDEvent].self, from: Data(contentsOf: dir.appendingPathComponent("events.json")))
        for event in events { _ = event.extras }
        let cds = events.filter { $0.eventType == "community-day" }
        // Every Community Day with extra data should list at least one spawn.
        for cd in cds where cd.extraData?["communityday"] != nil {
            XCTAssertFalse(cd.extras.spawns.isEmpty, cd.eventID)
        }
    }
}

final class GamemasterLookupTests: XCTestCase {
    private func lookup() throws -> GamemasterLookup {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        let gm = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        return GamemasterLookup(gm)
    }

    func testNormalisation() {
        XCTAssertEqual(GamemasterLookup.keys(for: "Meowth (Galarian)"), ["meowth galarian", "galarian meowth"])
        XCTAssertEqual(GamemasterLookup.normalize("Flabébé"), "flabebe")
        XCTAssertEqual(GamemasterLookup.normalize("Mr. Mime"), "mr mime")
    }

    func testFindsPlainAndRegionalNames() throws {
        let l = try lookup()
        XCTAssertEqual(l.pokemon(named: "Pawniard")?.speciesId, "pawniard")
        XCTAssertEqual(l.pokemon(named: "pawniard")?.speciesId, "pawniard")
        XCTAssertEqual(l.pokemon(named: "Galarian Meowth")?.speciesId, "meowth_galarian")
        XCTAssertNil(l.pokemon(named: "Definitely Not A Pokemon"))
    }

    func testPrefersBaseFormOverShadow() throws {
        let p = try XCTUnwrap(try lookup().pokemon(named: "Bulbasaur"))
        XCTAssertFalse(p.tags.contains("shadow"))
    }

    func testEvolutionLine() throws {
        let l = try lookup()
        let start = try XCTUnwrap(l.pokemon(named: "Pawniard"))
        let line = l.evolutionLine(from: start).map(\.speciesId)
        XCTAssertEqual(line.first, "pawniard")
        XCTAssertTrue(line.contains("bisharp"))
        XCTAssertTrue(line.contains("kingambit"))
    }

    func testMoveName() throws {
        let l = try lookup()
        XCTAssertEqual(l.moveName("SHADOW_BALL"), "Shadow Ball")
        XCTAssertEqual(l.moveName("NOT_A_REAL_MOVE"), "Not A Real Move")
    }
}
