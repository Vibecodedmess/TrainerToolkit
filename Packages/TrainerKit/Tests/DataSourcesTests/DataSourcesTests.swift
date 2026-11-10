import XCTest
@testable import DataSources

/// Phase 0: proves the test pipeline runs in CI. Decoding/caching tests come in Phase 1.
final class DataSourcesTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(DataSources.moduleName, "DataSources")
    }
}
