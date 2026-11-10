import XCTest
@testable import GameMath

/// Phase 0: proves the test pipeline runs in CI. Real CP/cost tests come in Phase 3.
final class GameMathTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(GameMath.moduleName, "GameMath")
    }
}
