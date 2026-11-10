import XCTest
@testable import SearchBuilder

final class SearchCatalogTests: XCTestCase {
    func testBundledCatalogIsWellFormed() throws {
        let catalog = try SearchCatalog.bundled()
        XCTAssertEqual(catalog.operators.and, "&")
        XCTAssertEqual(catalog.operators.or, ",")
        XCTAssertEqual(catalog.operators.not, "!")
        XCTAssertFalse(catalog.groups.isEmpty)

        let ids = catalog.allFilters.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "filter ids must be unique")

        for filter in catalog.allFilters {
            switch filter.kind {
            case .flag:
                XCTAssertFalse(filter.term?.isEmpty ?? true, filter.id)
            case .options:
                XCTAssertFalse(filter.options.isEmpty, filter.id)
                XCTAssertEqual(filter.options.count, Set(filter.options.map(\.id)).count, filter.id)
                XCTAssertTrue(filter.options.allSatisfy { !$0.term.isEmpty }, filter.id)
            case .range, .number, .text:
                XCTAssertNotNil(filter.prefix, filter.id)
            }
            if !filter.verified {
                XCTAssertNotNil(filter.note, "unverified filter \(filter.id) needs a note explaining why")
            }
        }
    }

    func testPresetsOnlyReferenceKnownFilters() throws {
        let catalog = try SearchCatalog.bundled()
        XCTAssertFalse(catalog.presets.isEmpty)
        for preset in catalog.presets {
            let state = preset.state
            let used = Set(state.flags.keys).union(state.options.keys).union(state.ranges.keys)
                .union(state.numbers.keys).union(state.texts.keys)
            for id in used {
                XCTAssertNotNil(catalog.filter(id: id), "\(preset.name) uses unknown filter \(id)")
            }
            for (filterID, picks) in state.options {
                let optionIDs = Set(catalog.filter(id: filterID)?.options.map(\.id) ?? [])
                XCTAssertTrue(Set(picks.keys).isSubset(of: optionIDs), "\(preset.name): bad option in \(filterID)")
            }
            XCTAssertFalse(SearchQueryBuilder.build(state, in: catalog).isEmpty, preset.name)
        }
    }
}

final class SearchQueryBuilderTests: XCTestCase {
    private var catalog: SearchCatalog!

    override func setUpWithError() throws {
        catalog = try SearchCatalog.bundled()
    }

    private func build(_ configure: (inout SearchState) -> Void) -> String {
        var state = SearchState()
        configure(&state)
        return SearchQueryBuilder.build(state, in: catalog)
    }

    func testEmptyStateBuildsEmptyString() {
        XCTAssertEqual(build { _ in }, "")
        XCTAssertTrue(SearchState().isEmpty)
    }

    func testFlagIncludeAndExclude() {
        XCTAssertEqual(build { $0.flags["shiny"] = .include }, "shiny")
        XCTAssertEqual(build { $0.flags["shiny"] = .exclude }, "!shiny")
        XCTAssertEqual(build { $0.flags["shiny"] = .include; $0.flags["lucky"] = .exclude }, "shiny&!lucky")
    }

    func testIncludedOptionsAreOredAndExcludedOnesAreSeparateClauses() {
        let result = build {
            $0.options["stars"] = ["0": .include, "1": .include, "4": .exclude]
        }
        XCTAssertEqual(result, "0*,1*&!4*")
    }

    func testOptionOrderFollowsCatalogNotSelectionOrder() {
        let result = build { $0.options["type"] = ["fairy": .include, "fire": .include, "normal": .include] }
        XCTAssertEqual(result, "normal,fire,fairy")
    }

    func testRanges() {
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue(min: 100, max: 500) }, "cp100-500")
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue(min: 300) }, "cp300-")
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue(max: 300) }, "cp-300")
        XCTAssertEqual(build { $0.ranges["hp"] = RangeValue(min: 150, max: 150) }, "hp150")
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue(min: 500, max: 100) }, "cp100-500", "swapped bounds")
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue() }, "", "empty range adds nothing")
        XCTAssertEqual(build { $0.ranges["cp"] = RangeValue(max: 100, inclusion: .exclude) }, "!cp-100")
    }

    func testRangesAreClampedToTheFiltersBounds() {
        XCTAssertEqual(build { $0.ranges["buddy"] = RangeValue(min: -3, max: 9) }, "buddy0-5")
        XCTAssertEqual(build { $0.ranges["mega"] = RangeValue(min: 0, max: 2) }, "mega1-2")
    }

    func testNumber() {
        XCTAssertEqual(build { $0.numbers["year"] = 2016 }, "year2016")
    }

    func testTextEntries() {
        let result = build {
            $0.texts["family"] = [TextEntry(value: "Pikachu"), TextEntry(value: "eevee"), TextEntry(value: "magikarp", inclusion: .exclude)]
        }
        XCTAssertEqual(result, "+pikachu,+eevee&!+magikarp")
    }

    func testTextIsSanitized() {
        XCTAssertEqual(build { $0.texts["move"] = [TextEntry(value: "  @Scratch ")] }, "@scratch")
        XCTAssertEqual(build { $0.texts["tag"] = [TextEntry(value: "#pvp&raid")] }, "#pvpraid")
        XCTAssertEqual(build { $0.texts["name"] = [TextEntry(value: "mr.   mime")] }, "mr. mime")
        XCTAssertEqual(build { $0.texts["name"] = [TextEntry(value: " ,;! ")] }, "", "nothing left after cleaning")
    }

    func testGroupsAreJoinedWithAndInCatalogOrder() {
        let result = build {
            $0.texts["family"] = [TextEntry(value: "pikachu")]
            $0.ranges["cp"] = RangeValue(min: 1500)
            $0.flags["shiny"] = .include
            $0.options["stars"] = ["4": .include]
        }
        XCTAssertEqual(result, "4*&shiny&cp1500-&+pikachu")
    }

    func testBuiltInPresets() throws {
        func preset(_ name: String) throws -> String {
            let p = try XCTUnwrap(catalog.presets.first { $0.name == name }, name)
            return SearchQueryBuilder.build(p.state, in: catalog)
        }
        XCTAssertEqual(try preset("Safe to transfer"),
                       "0*,1*,2*&!shiny&!lucky&!shadow&!purified&!legendary&!mythical&!ultrabeast&!costume&!background&!favorite&!#")
        XCTAssertEqual(try preset("New Pokédex evolutions"), "evolve&evolvenew")
        XCTAssertEqual(try preset("Perfect (4★)"), "4*")
        XCTAssertEqual(try preset("Caught today"), "age0")
    }

    func testUnverifiedNotes() {
        var state = SearchState()
        XCTAssertTrue(SearchQueryBuilder.unverifiedNotes(for: state, in: catalog).isEmpty)

        state.flags["shiny"] = .include
        XCTAssertTrue(SearchQueryBuilder.unverifiedNotes(for: state, in: catalog).isEmpty, "verified term, no OR")

        state.flags["anytag"] = .exclude
        XCTAssertEqual(SearchQueryBuilder.unverifiedNotes(for: state, in: catalog).count, 1)

        state.options["stars"] = ["0": .include, "1": .include]
        let notes = SearchQueryBuilder.unverifiedNotes(for: state, in: catalog)
        XCTAssertEqual(notes.count, 2, "adds the AND/OR precedence note")
    }

    func testStateRoundTripsThroughJSON() throws {
        var state = SearchState()
        state.flags["shiny"] = .exclude
        state.options["stars"] = ["4": .include]
        state.ranges["cp"] = RangeValue(min: 10, max: 20, inclusion: .exclude)
        state.numbers["year"] = 2020
        state.texts["tag"] = [TextEntry(value: "pvp")]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SearchState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testSanitizeDropsRepeatedPrefix() {
        XCTAssertEqual(SearchQueryBuilder.sanitize("++Eevee", dropping: "+"), "eevee")
        XCTAssertEqual(SearchQueryBuilder.sanitize("pikachu", dropping: ""), "pikachu")
    }
}
