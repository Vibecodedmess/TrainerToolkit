import XCTest
@testable import GameMath
import DataSources

/// Checks the bundled evolution files against each other and against PvPoke's species list.
/// No remembered game values: expectations come from the files themselves or made-up ids.
final class EvolutionTablesTests: XCTestCase {
    private var tables: EvolutionTables!
    private var guide: EvolutionItemGuide!

    override func setUpWithError() throws {
        tables = try EvolutionTables.bundled()
        guide = try EvolutionItemGuide.bundled()
    }

    func testEveryReferencedItemAndQuestHasText() {
        XCTAssertGreaterThan(tables.branches.count, 100)
        for b in tables.branches {
            for id in [b.item, b.lure].compactMap({ $0 }) {
                let item = tables.item(id)
                XCTAssertNotNil(item, id)
                XCTAssertFalse(item?.name.isEmpty ?? true, id)
            }
            if let q = b.quest {
                let text = tables.quest(q)?.text ?? ""
                XCTAssertFalse(text.isEmpty, q)
                XCTAssertFalse(text.contains("{0}"), "placeholder left in \(q)")
            }
        }
    }

    func testCommunityGuideCoversExactlyTheItemsInTheData() {
        XCTAssertEqual(Set(guide.items.keys), Set(tables.items.map(\.id)))
        XCTAssertTrue(guide.items.values.allSatisfy { !$0.isEmpty })
        XCTAssertFalse(guide.source.pages.isEmpty)
        XCTAssertFalse(guide.source.license.isEmpty)
    }

    func testSpeciesKeys() {
        // Made-up ids, following the game master's naming.
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO", form: nil), "foo")
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO", form: "FOO_NORMAL"), "foo")
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO", form: "FOO_ALOLA"), "foo_alolan")
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO", form: "FOO_GALARIAN"), "foo_galarian")
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO", form: "FOO_PALDEA"), "foo_paldean")
        XCTAssertEqual(EvolutionTables.speciesKey(pokemonId: "FOO_BAR", form: "FOO_BAR_SPOTTED"), "foo_bar_spotted")
    }

    func testLookupIgnoresShadowAndKeepsRegionalFormsApart() throws {
        let regional = try XCTUnwrap(tables.branches.first { b in
            let key = EvolutionTables.speciesKey(pokemonId: b.pokemonId, form: b.form)
            return EvolutionTables.isRegional(key)
        })
        let key = EvolutionTables.speciesKey(pokemonId: regional.pokemonId, form: regional.form)
        XCTAssertTrue(tables.branches(forSpecies: key).contains(regional))
        XCTAssertTrue(tables.branches(forSpecies: key + "_shadow").contains(regional))
        // The plain species does not get the regional form's evolutions.
        XCTAssertFalse(tables.branches(forSpecies: regional.pokemonId.lowercased()).contains(regional))
    }

    func testMostItemEvolutionsMatchPvPokeSpecies() throws {
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        let gm = try JSONDecoder().decode(Gamemaster.self, from: Data(contentsOf: dir.appendingPathComponent("gamemaster.json")))
        let ids = Set(gm.pokemon.map(\.speciesId))
        let withItem = tables.branches.filter { $0.item != nil || $0.lure != nil }
        XCTAssertFalse(withItem.isEmpty)
        let matched = withItem.filter { ids.contains(EvolutionTables.speciesKey(pokemonId: $0.pokemonId, form: $0.form)) }
        // Some game master forms have no PvPoke entry; the large majority must match.
        XCTAssertGreaterThan(Double(matched.count) / Double(withItem.count), 0.8)
        // And they are found through the species lookup.
        for b in matched {
            let key = EvolutionTables.speciesKey(pokemonId: b.pokemonId, form: b.form)
            XCTAssertTrue(tables.branches(forSpecies: key).contains { $0.evolution == b.evolution && $0.item == b.item && $0.lure == b.lure }, key)
        }
    }
}
