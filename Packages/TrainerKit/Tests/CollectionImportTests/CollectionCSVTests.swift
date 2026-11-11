import XCTest
@testable import CollectionImport
import DataSources
import GameMath

final class CollectionCSVTests: XCTestCase {
    private var lookup: GamemasterLookup!
    private var levels: LevelTables!

    override func setUpWithError() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        let gm = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        lookup = GamemasterLookup(gm)
        levels = try LevelTables.bundled()
    }

    /// CP computed with the app's own formula, so tests don't depend on remembered values.
    private func cp(_ name: String, _ a: Int, _ d: Int, _ h: Int, level: Double) throws -> Int {
        let p = try XCTUnwrap(lookup.pokemon(named: name))
        let base = BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
        return try XCTUnwrap(CPCalculator.cp(base: base, ivs: IVs(attack: a, defense: d, stamina: h), level: PokemonLevel(level), tables: levels))
    }

    private func run(_ csv: String) throws -> CollectionCSV.Resolved {
        CollectionCSV.resolve(CollectionCSV.parse(try CSVReader.read(csv)), lookup: lookup, levels: levels)
    }

    func testTemplateHeaderParsesAsAllColumns() throws {
        let table = try CSVReader.read(CollectionCSV.templateHeader)
        XCTAssertTrue(CollectionCSV.parse(table).missingColumns.isEmpty)
        XCTAssertEqual(table.headers.count, CollectionCSV.Column.allCases.count)
    }

    func testMinimalRowDerivesLevelFromCP() throws {
        let value = try cp("Bulbasaur", 15, 14, 13, level: 25.5)
        let result = try run("Name,CP,Attack,Defense,HP\nBulbasaur,\(value),15,14,13\n")
        XCTAssertTrue(result.problems.isEmpty, "\(result.problems)")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(c.speciesId, "bulbasaur")
        XCTAssertEqual(c.ivs, IVs(attack: 15, defense: 14, stamina: 13))
        XCTAssertTrue(CPCalculator.levels(matchingCP: value, base: c.base, ivs: c.ivs, maxLevel: levels.maxBestBuddyLevel, tables: levels).contains(c.level))
        XCTAssertEqual(CPCalculator.cp(base: c.base, ivs: c.ivs, level: c.level, tables: levels), value)
    }

    func testSemicolonFileWithAliasesMovesAndFlags() throws {
        let value = try cp("Bulbasaur", 10, 12, 14, level: 30)
        let csv = """
        Pokémon;CP;Atk;Def;Sta;Fast;Charged;Charged move 2;Shiny;Lucky;Nickname
        Bulbasaur;\(value);10;12;14;vine whip;SLUDGE_BOMB;Seed Bomb;yes;x;Bobby
        """
        let result = try run(csv)
        XCTAssertTrue(result.problems.isEmpty, "\(result.problems)")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(c.fastMoveId, "VINE_WHIP")
        XCTAssertEqual(c.chargedMoveId, "SLUDGE_BOMB")
        XCTAssertEqual(c.secondChargedMoveId, "SEED_BOMB")
        XCTAssertTrue(c.isShiny)
        XCTAssertTrue(c.isLucky)
        XCTAssertEqual(c.nickname, "Bobby")
        XCTAssertTrue(c.warnings.isEmpty, "\(c.warnings)")
    }

    func testRegionalAndShadowNames() throws {
        let meowth = try cp("Galarian Meowth", 1, 2, 3, level: 20)
        let bulba = try cp("Bulbasaur", 5, 5, 5, level: 25)
        let csv = """
        Name,CP,Attack,Defense,HP,Shadow
        Galarian Meowth,\(meowth),1,2,3,
        Shadow Bulbasaur,\(bulba),5,5,5,
        Bulbasaur (Shadow),\(bulba),5,5,5,
        Bulbasaur,\(bulba),5,5,5,yes
        """
        let result = try run(csv)
        XCTAssertTrue(result.problems.isEmpty, "\(result.problems)")
        XCTAssertEqual(result.candidates.map(\.speciesId), ["meowth_galarian", "bulbasaur", "bulbasaur", "bulbasaur"])
        XCTAssertEqual(result.candidates.map(\.isShadow), [false, true, true, true])
    }

    func testLevelColumnWinsAndMismatchedCPWarns() throws {
        let result = try run("Name,CP,Level,Attack,Defense,HP\nBulbasaur,10,30.5,15,15,15\n")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(c.level, PokemonLevel(30.5))
        XCTAssertEqual(c.warnings.count, 1)
    }

    func testRowProblemsAreReportedWithLineNumbers() throws {
        let csv = """
        Name,CP,Attack,Defense,HP,Shiny
        Notapokemon,500,1,2,3,
        Bulbasaur,500,16,2,3,
        Bulbasaur,,1,2,3,
        Bulbasaur,999999,1,2,3,
        Bulbasaur,500,1,2,3,maybe
        ,,,,,
        """
        let result = try run(csv)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(result.problems.count, 5)
        XCTAssertEqual(Set(result.problems.map(\.line)), [2, 3, 4, 5, 6], "the empty last row is skipped silently")
    }

    func testMissingRequiredColumns() throws {
        let parsed = CollectionCSV.parse(try CSVReader.read("Name,Attack\nBulbasaur,1\n"))
        XCTAssertEqual(Set(parsed.missingColumns), ["Defense", "HP", "CP (or Level)"])
        XCTAssertTrue(parsed.rows.isEmpty)
    }

    func testUnknownMoveIsDroppedWithWarning() throws {
        let value = try cp("Bulbasaur", 1, 1, 1, level: 20)
        let result = try run("Name,CP,Attack,Defense,HP,Fast move\nBulbasaur,\(value),1,1,1,Totally Made Up\n")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(c.fastMoveId, "")
        XCTAssertEqual(c.warnings.count, 1)
    }

    func testShadowCannotBeLucky() throws {
        let value = try cp("Bulbasaur", 1, 1, 1, level: 20)
        let result = try run("Name,CP,Attack,Defense,HP,Shadow,Lucky\nBulbasaur,\(value),1,1,1,yes,yes\n")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertTrue(c.isShadow)
        XCTAssertFalse(c.isLucky)
        XCTAssertFalse(c.warnings.isEmpty)
    }

    /// The example in COLLECTION_IMPORT.md must import cleanly.
    func testDocumentedExample() throws {
        let csv = """
        Name,CP,Attack,Defense,HP,Fast move,Charged move,Second charged move,Shadow,Purified,Shiny,Lucky,Level,Nickname,Notes
        Bulbasaur,,15,14,13,Vine Whip,Sludge Bomb,,no,no,no,no,25,,
        """
        let result = try run(csv)
        XCTAssertTrue(result.problems.isEmpty, "\(result.problems)")
        let c = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(c.level, PokemonLevel(25))
        XCTAssertEqual(c.fastMoveId, "VINE_WHIP")
        XCTAssertTrue(c.warnings.isEmpty, "\(c.warnings)")
    }

    func testMoveIdLookup() {
        XCTAssertEqual(lookup.moveId(named: "Vine Whip"), "VINE_WHIP")
        XCTAssertEqual(lookup.moveId(named: "vine_whip"), "VINE_WHIP")
        XCTAssertNil(lookup.moveId(named: "Nope Nope"))
    }
}
