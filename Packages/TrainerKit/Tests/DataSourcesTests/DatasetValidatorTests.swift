import XCTest
@testable import DataSources

final class DatasetValidatorTests: XCTestCase {
    func testAllFixturesValidate() throws {
        for id in DataSourceID.allCases {
            let counts = try DatasetValidator.validate(Fixtures.json(for: id), for: id)
            XCTAssertFalse(counts.isEmpty, "\(id)")
            XCTAssertTrue(counts.allSatisfy { $0.value > 0 }, "\(id)")
        }
    }

    func testGamemasterCountsAndDefaults() throws {
        let counts = try DatasetValidator.validate(Fixtures.json(for: .gamemaster), for: .gamemaster)
        XCTAssertEqual(counts, [DatasetCount(label: "Pokémon", value: 2), DatasetCount(label: "Moves", value: 2)])

        let gm = try JSONDecoder().decode(Gamemaster.self, from: Fixtures.json(for: .gamemaster))
        XCTAssertEqual(gm.pokemon[0].realTypes, ["grass"])
        XCTAssertEqual(gm.pokemon[1].fastMoves, []) // missing list defaults to empty
        XCTAssertTrue(gm.pokemon[1].released)
        XCTAssertTrue(gm.moves[0].isFastMove)
        XCTAssertFalse(gm.moves[1].isFastMove)
    }

    func testRejectsInvalidJSON() {
        XCTAssertThrowsError(try DatasetValidator.validate(Data("<html>oops</html>".utf8), for: .events))
        XCTAssertThrowsError(try DatasetValidator.validate(Data(), for: .gamemaster))
    }

    func testRejectsChangedShape() {
        // An object where an array is expected.
        XCTAssertThrowsError(try DatasetValidator.validate(Data(#"{"events":[]}"#.utf8), for: .events))
        // Gamemaster without the "pokemon" key.
        XCTAssertThrowsError(try DatasetValidator.validate(Data(#"{"moves":[]}"#.utf8), for: .gamemaster))
    }

    func testRejectsEmptyData() {
        XCTAssertThrowsError(try DatasetValidator.validate(Data("[]".utf8), for: .raids))
    }

    func testToleratesAFewOddEntries() throws {
        var items = (1...20).map { #"{"name":"Boss\#($0)","tier":"1-Star Raids"}"# }
        items.append(#"{"unexpected":true}"#)
        let data = Data("[\(items.joined(separator: ","))]".utf8)
        let counts = try DatasetValidator.validate(data, for: .raids)
        XCTAssertEqual(counts.first?.value, 20)
    }

    func testRejectsMostlyUnreadableEntries() {
        let data = Data(#"[{"name":"A","tier":"1"},{"x":1},{"x":2},{"x":3}]"#.utf8)
        XCTAssertThrowsError(try DatasetValidator.validate(data, for: .raids))
    }
}
