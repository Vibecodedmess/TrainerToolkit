import XCTest
@testable import DataSources

/// Guards the snapshots that ship in the app: if a refreshed snapshot no longer matches the
/// models, CI fails here instead of the app silently showing nothing.
final class BundledSnapshotTests: XCTestCase {
    func testEverySnapshotIsPresentAndValid() throws {
        let directory = try XCTUnwrap(BundledSnapshots.directory, "Snapshots folder missing from bundle")
        for id in DataSourceID.allCases {
            let url = directory.appendingPathComponent(id.descriptor.fileName)
            let data = try Data(contentsOf: url)
            let counts = try DatasetValidator.validate(data, for: id)
            XCTAssertTrue(counts.allSatisfy { $0.value > 0 }, "\(id): \(counts)")
        }
    }

    func testManifestDatesEverySnapshot() throws {
        let directory = try XCTUnwrap(BundledSnapshots.directory)
        let dates = BundledSnapshots.fetchDates(in: directory)
        XCTAssertEqual(Set(dates.keys), Set(DataSourceID.allCases))
    }

    func testRealGamemasterHasPlausibleSize() throws {
        let directory = try XCTUnwrap(BundledSnapshots.directory)
        let data = try Data(contentsOf: directory.appendingPathComponent("gamemaster.json"))
        let gm = try JSONDecoder().decode(Gamemaster.self, from: data)
        XCTAssertGreaterThan(gm.pokemon.count, 1000)
        XCTAssertGreaterThan(gm.moves.count, 200)
        XCTAssertEqual(gm.skippedEntries, 0, "some gamemaster entries no longer match the model")
    }
}
