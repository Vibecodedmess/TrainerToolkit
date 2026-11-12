import XCTest
@testable import ScreenshotImport
import DataSources
import GameMath

/// No real screenshots or remembered game values: layouts are made up to match the English UI,
/// numbers are computed from the bundled tables.
final class ScreenshotImportTests: XCTestCase {
    private var gamemaster: Gamemaster!
    private var lookup: GamemasterLookup!
    private var levels: LevelTables!

    override func setUpWithError() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        gamemaster = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        lookup = GamemasterLookup(gamemaster)
        levels = try LevelTables.bundled()
    }

    private func line(_ text: String, x: Double, y: Double, w: Double = 0.2, h: Double = 0.02) -> RecognizedLine {
        RecognizedLine(text, TextBox(x: x, y: y, width: w, height: h))
    }

    /// A species with an evolution family, a non-empty move list and ordinary entries.
    private func evolvedSpecies() throws -> (GMPokemon, GMPokemon) {
        for root in gamemaster.pokemon where root.released && (root.family?.parent == nil) && !(root.family?.evolutions ?? []).isEmpty {
            guard !root.tags.contains("shadow"), !root.speciesName.contains("(") else { continue }
            let line = lookup.evolutionLine(from: root)
            if let last = line.last, last.speciesId != root.speciesId, !last.speciesName.contains("("), !last.fastMoves.isEmpty {
                return (root, last)
            }
        }
        throw XCTSkip("No evolution family in the data")
    }

    private func base(_ p: GMPokemon) -> BaseStats {
        BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
    }

    // MARK: - Parser

    func testParsesDetailScreenLayout() {
        let lines = [
            line("09:09", x: 0.05, y: 0.02),
            line("CP1234", x: 0.35, y: 0.06, w: 0.3, h: 0.03),
            line("Examplemon", x: 0.35, y: 0.41, w: 0.3, h: 0.03),
            line("87 / 100 HP", x: 0.4, y: 0.46),
            line("ICE", x: 0.45, y: 0.56, w: 0.1),
            line("EXAMPLE CANDY", x: 0.4, y: 0.62),
            line("POWER UP", x: 0.1, y: 0.7, w: 0.3, h: 0.03),
            line("2,500", x: 0.55, y: 0.705, w: 0.12),
            line("3", x: 0.78, y: 0.705, w: 0.03),
            line("GYMS & RAIDS", x: 0.2, y: 0.78),
            line("TRAINER BATTLES", x: 0.55, y: 0.78),
            line("Ice Shard", x: 0.12, y: 0.82),
            line("10", x: 0.88, y: 0.82, w: 0.05),
            line("Icy Wind —", x: 0.12, y: 0.86),
            line("NEW ATTACK", x: 0.1, y: 0.9),
            line("75,000", x: 0.5, y: 0.9),
        ]
        let r = ScreenshotParser.parse(lines)
        XCTAssertEqual(r.cp, 1234)
        XCTAssertEqual(r.hp, 100)
        XCTAssertEqual(r.name, "Examplemon")
        XCTAssertEqual(r.candyFamily, "Example")
        XCTAssertEqual(r.types, ["ice"])
        XCTAssertEqual(r.powerUpStardust, 2500)
        XCTAssertEqual(r.powerUpCandy, 3)
        XCTAssertEqual(r.moveLines, ["Ice Shard", "Icy Wind"])
        XCTAssertFalse(r.isShadow)
    }

    func testCPIgnoresOverlaysAndStatusBar() {
        let lines = [
            line("100", x: 0.86, y: 0.02, w: 0.06),
            line("♀L21 47% 7/3/11", x: 0.56, y: 0.085, w: 0.38),
            line("C1718", x: 0.34, y: 0.055, w: 0.26, h: 0.03),
        ]
        XCTAssertEqual(ScreenshotParser.parse(lines).cp, 1718)
    }

    func testAppraisalLabelsShadowAndMerge() {
        let appraisal = ScreenshotParser.parse([
            line("Attack", x: 0.12, y: 0.72, w: 0.1),
            line("Defense", x: 0.12, y: 0.76, w: 0.1),
            line("HP", x: 0.12, y: 0.80, w: 0.04),
            line("PURIFY", x: 0.2, y: 0.9),
        ])
        XCTAssertEqual(Set(appraisal.appraisalLabels.keys), Set(AppraisalStat.allCases))
        XCTAssertTrue(appraisal.isShadow)
        var detail = ScreenReading()
        detail.cp = 500
        let merged = detail.merged(with: appraisal)
        XCTAssertEqual(merged.cp, 500)
        XCTAssertTrue(merged.isShadow)
        XCTAssertEqual(merged.appraisalLabels.count, 3)
    }

    func testScrolledScreenReadsTheNameAtTheTop() {
        let r = ScreenshotParser.parse([
            line("09:09", x: 0.05, y: 0.02, w: 0.15),
            line("Examplemon", x: 0.38, y: 0.012, w: 0.24, h: 0.03),
            line("POWER UP", x: 0.1, y: 0.33, w: 0.3, h: 0.03),
            line("2,500", x: 0.55, y: 0.335, w: 0.12),
        ])
        XCTAssertNil(r.cp)
        XCTAssertEqual(r.name, "Examplemon")
        XCTAssertEqual(r.powerUpStardust, 2500)
    }

    // MARK: - Grouping

    private func reading(cp: Int? = nil, hp: Int? = nil, name: String? = nil, family: String? = nil) -> ScreenReading {
        var r = ScreenReading()
        r.cp = cp
        r.hp = hp
        r.name = name
        r.candyFamily = family
        return r
    }

    func testGroupingSplitsPerPokemon() {
        let readings = [
            reading(cp: 900, hp: 80, name: "Alpha"),          // A top
            reading(name: "Alpha", family: "Alpha"),          // A scrolled
            reading(cp: 900, hp: 80, name: "Alpha"),          // A appraisal
            reading(name: "Beta"),                            // B scrolled (before its top)
            reading(cp: 1500, hp: 120, name: "Beta"),         // B top
            reading(cp: 1500, hp: 121, name: "Beta"),         // C: same name and CP, other HP
            reading(),                                        // nothing read: joins C
        ]
        XCTAssertEqual(ScreenshotGrouping.group(readings), [[0, 1, 2], [3, 4], [5, 6]])
        XCTAssertEqual(ScreenshotGrouping.group([]), [])
    }

    func testCertainChoiceNeedsOneAnswer() throws {
        let (_, p) = try evolvedSpecies()
        let level = PokemonLevel(25), ivs = IVs(attack: 6, defense: 11, stamina: 2)
        let r = try reading(for: p, name: p.speciesName, level: level, ivs: ivs)
        let bars: [AppraisalStat: Double] = [.attack: 6.0 / 15, .defense: 11.0 / 15, .hp: 2.0 / 15]
        let withBars = try XCTUnwrap(ScreenshotImporter.propose(r, barFractions: bars, gamemaster: gamemaster, lookup: lookup, tables: levels))
        if withBars.options.count == 1 {
            let choice = try XCTUnwrap(withBars.certainChoice)
            XCTAssertEqual(choice.solution.ivs, ivs)
            XCTAssertEqual(choice.solution.level, level)
        }
        // Without bars: only certain when exactly one combination fits.
        let noBars = try XCTUnwrap(ScreenshotImporter.propose(r, barFractions: [:], gamemaster: gamemaster, lookup: lookup, tables: levels))
        if let option = noBars.options.first, noBars.options.count == 1 {
            XCTAssertEqual(noBars.certainChoice != nil, option.solutions.count == 1)
        }
    }

    func testIntegersWithSeparators() {
        XCTAssertEqual(ScreenshotParser.integers(in: "5,000 4"), [5000, 4])
        XCTAssertEqual(ScreenshotParser.integers(in: "143,144"), [143144])
        XCTAssertEqual(ScreenshotParser.integers(in: "12.000"), [12000])
    }

    // MARK: - Bars

    private func row(filled: Int, empty: Int, dividersAt: [Int] = [], trailingNoise: Bool = false) -> [AppraisalBars.Pixel] {
        let white = AppraisalBars.Pixel(r: 255, g: 255, b: 255)
        let orange = AppraisalBars.Pixel(r: 240, g: 150, b: 40)
        let grey = AppraisalBars.Pixel(r: 225, g: 225, b: 225)
        var pixels = Array(repeating: white, count: 20)
        for i in 0..<(filled + empty) {
            pixels.append(dividersAt.contains(i) ? white : (i < filled ? orange : grey))
        }
        pixels += Array(repeating: white, count: 30)
        if trailingNoise { pixels += Array(repeating: orange, count: 40) }
        return pixels
    }

    func testBarFractionWithDividersAndNoiseAfterTheCard() throws {
        // 13 of 15 filled; dividers inside the filled part; something colourful right of the card.
        let width = 300
        let filled = width * 13 / 15
        let m = try XCTUnwrap(AppraisalBars.measure(row(filled: filled, empty: width - filled, dividersAt: [100, 101, 200, 201], trailingNoise: true)))
        XCTAssertEqual(m.length, width)
        XCTAssertEqual(AppraisalBars.iv(fromFraction: m.fraction), 13)
    }

    func testEmptyAndFullBars() throws {
        XCTAssertEqual(AppraisalBars.iv(fromFraction: try XCTUnwrap(AppraisalBars.measure(row(filled: 0, empty: 300))).fraction), 0)
        XCTAssertEqual(AppraisalBars.iv(fromFraction: try XCTUnwrap(AppraisalBars.measure(row(filled: 300, empty: 0))).fraction), 15)
        XCTAssertNil(AppraisalBars.measure(Array(repeating: AppraisalBars.Pixel(r: 255, g: 255, b: 255), count: 50)))
    }

    /// Rows between the bars: white up to the card's edge, then something colourful. Not a bar.
    func testRowsWithoutABarNearTheStartAreIgnored() {
        let white = AppraisalBars.Pixel(r: 255, g: 255, b: 255)
        let orange = AppraisalBars.Pixel(r: 240, g: 150, b: 40)
        let stray = Array(repeating: white, count: 400) + Array(repeating: orange, count: 500)
        XCTAssertNil(AppraisalBars.measure(stray, maxStart: 60))
        let rows = [stray, stray, stray, row(filled: 280, empty: 20)]
        XCTAssertEqual(AppraisalBars.iv(fromFraction: AppraisalBars.fraction(rows: rows, minLength: 100, maxStart: 60) ?? -1), 14)
    }

    func testMedianOverRowsIgnoresShortEdges() {
        let rows = [row(filled: 10, empty: 5), row(filled: 160, empty: 140), row(filled: 160, empty: 140), row(filled: 161, empty: 139)]
        let f = AppraisalBars.fraction(rows: rows, minLength: 100)
        XCTAssertEqual(AppraisalBars.iv(fromFraction: f ?? -1), 8)
    }

    // MARK: - Solver

    func testSolverFindsTheTruthAndBarsPinItDown() throws {
        let (_, p) = try evolvedSpecies()
        let truthLevel = PokemonLevel(23.5)
        let truth = IVs(attack: 9, defense: 13, stamina: 6)
        let cp = try XCTUnwrap(CPCalculator.cp(base: base(p), ivs: truth, level: truthLevel, tables: levels))
        let hp = try XCTUnwrap(CPCalculator.hp(base: base(p), ivs: truth, level: truthLevel, tables: levels))
        let dust = PowerUpCalculator.cost(from: truthLevel, to: truthLevel.next, tables: levels).stardust

        let loose = IVSolver.solve(base: base(p), cp: cp, hp: hp, powerUpStardust: dust, modifiers: .none, tables: levels)
        XCTAssertTrue(loose.contains { $0.level == truthLevel && $0.ivs == truth })
        for s in loose {
            XCTAssertEqual(CPCalculator.cp(base: base(p), ivs: s.ivs, level: s.level, tables: levels), cp)
            XCTAssertEqual(PowerUpCalculator.cost(from: s.level, to: s.level.next, tables: levels).stardust, dust)
        }

        let hinted = IVSolver.solve(base: base(p), cp: cp, hp: hp, powerUpStardust: dust, modifiers: .none,
                                    hints: .init(attack: 9, defense: 13, stamina: 6), tables: levels)
        let first = try XCTUnwrap(hinted.first)
        XCTAssertEqual(first.ivs, truth)
        XCTAssertEqual(first.level, truthLevel)
        XCTAssertEqual(first.distance, 0)
        XCTAssertLessThanOrEqual(hinted.count, loose.count)
    }

    func testLuckyDustIsUsed() throws {
        let (_, p) = try evolvedSpecies()
        let level = PokemonLevel(31)
        let ivs = IVs(attack: 15, defense: 15, stamina: 15)
        let cp = try XCTUnwrap(CPCalculator.cp(base: base(p), ivs: ivs, level: level, tables: levels))
        let lucky = CostModifiers(isLucky: true)
        let dust = PowerUpCalculator.cost(from: level, to: level.next, modifiers: lucky, tables: levels).stardust
        let solutions = IVSolver.solve(base: base(p), cp: cp, hp: nil, powerUpStardust: dust, modifiers: lucky, tables: levels)
        XCTAssertTrue(solutions.contains { $0.level == level && $0.ivs == ivs })
    }

    // MARK: - Importer

    private func reading(for p: GMPokemon, name: String?, level: PokemonLevel, ivs: IVs) throws -> ScreenReading {
        var r = ScreenReading()
        r.cp = try XCTUnwrap(CPCalculator.cp(base: base(p), ivs: ivs, level: level, tables: levels))
        r.hp = CPCalculator.hp(base: base(p), ivs: ivs, level: level, tables: levels)
        r.name = name
        r.powerUpStardust = PowerUpCalculator.cost(from: level, to: level.next, tables: levels).stardust
        return r
    }

    func testImporterBySpeciesNameWithBars() throws {
        let (_, p) = try evolvedSpecies()
        let level = PokemonLevel(26), ivs = IVs(attack: 4, defense: 15, stamina: 10)
        let r = try reading(for: p, name: p.speciesName, level: level, ivs: ivs)
        let bars: [AppraisalStat: Double] = [.attack: 4.0 / 15, .defense: 1, .hp: 10.0 / 15]
        let proposal = try XCTUnwrap(ScreenshotImporter.propose(r, barFractions: bars, gamemaster: gamemaster, lookup: lookup, tables: levels))
        let option = try XCTUnwrap(proposal.options.first { $0.pokemon.speciesId == p.speciesId })
        XCTAssertEqual(option.solutions.first?.ivs, ivs)
        XCTAssertEqual(option.solutions.first?.level, level)
    }

    func testImporterFallsBackToCandyFamilyForNicknames() throws {
        let (root, p) = try evolvedSpecies()
        var r = try reading(for: p, name: "Not A Species Name", level: PokemonLevel(20), ivs: IVs(attack: 1, defense: 2, stamina: 3))
        r.candyFamily = root.speciesName
        let proposal = try XCTUnwrap(ScreenshotImporter.propose(r, barFractions: [:], gamemaster: gamemaster, lookup: lookup, tables: levels))
        XCTAssertTrue(proposal.options.contains { $0.pokemon.speciesId == p.speciesId })
    }

    func testMovesAreReadForTheSpecies() throws {
        let (_, p) = try evolvedSpecies()
        let options = lookup.moveOptions(for: p)
        let fast = try XCTUnwrap(options.fast.first)
        let charged = try XCTUnwrap(options.charged.first)
        var r = try reading(for: p, name: p.speciesName, level: PokemonLevel(20), ivs: IVs(attack: 10, defense: 10, stamina: 10))
        r.moveLines = ["WEIGHT", fast.name, "Not a move", charged.name]
        let proposal = try XCTUnwrap(ScreenshotImporter.propose(r, barFractions: [:], gamemaster: gamemaster, lookup: lookup, tables: levels))
        let moves = proposal.moves(for: p, lookup: lookup)
        XCTAssertEqual(moves.fast, fast.id)
        XCTAssertEqual(moves.charged, [charged.id])
    }
}
