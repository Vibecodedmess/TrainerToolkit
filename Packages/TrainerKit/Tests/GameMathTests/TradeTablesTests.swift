import XCTest
@testable import GameMath

final class TradeTablesTests: XCTestCase {
    /// Made-up numbers (not game data), to test decoding and math in isolation.
    private static let fixtureJSON = """
    {
      "source": {"name": "fixture", "url": "https://example.invalid", "commit": "0000000", "extracted": "2000-01-01", "templates": ["FIXTURE"]},
      "friendshipLevels": [
        {"level": 1, "minPointsToReach": 5, "relativePointsToReach": null, "milestoneXpReward": 10,
         "attackBonusPercentage": 1.5, "raidBallBonus": null, "tradingDiscount": 0.25,
         "unlockedTrading": ["AAA_IN_POKEDEX", "BBB_NON_POKEDEX"], "unlockedLuckyFriendApplicator": true},
        {"level": 0, "minPointsToReach": null, "milestoneXpReward": 1,
         "attackBonusPercentage": 1.0, "tradingDiscount": null,
         "unlockedTrading": ["AAA_IN_POKEDEX"], "unlockedLuckyFriendApplicator": false}
      ],
      "remoteTrade": {"maxRemoteTradesPerDay": 7}
    }
    """

    private func fixture() throws -> TradeTables {
        try JSONDecoder().decode(TradeTables.self, from: Data(Self.fixtureJSON.utf8))
    }

    // MARK: - Bundled data (shape only; values are read from the file, never typed in here)

    func testBundledShape() throws {
        let tables = try TradeTables.bundled()
        XCTAssertFalse(tables.source.commit.isEmpty)
        XCTAssertGreaterThan(tables.friendshipLevels.count, 1)
        // Levels are contiguous from 0, so a level number is also its index.
        XCTAssertEqual(tables.friendshipLevels.map(\.level), Array(0..<tables.friendshipLevels.count))
        XCTAssertEqual(tables.maxLevel, tables.friendshipLevels.count - 1)
        for level in tables.friendshipLevels {
            XCTAssertFalse(level.unlockedTrading.isEmpty, "level \(level.level) unlocks no trades")
            if let discount = level.tradingDiscount {
                XCTAssertGreaterThan(discount, 0)
                XCTAssertLessThan(discount, 1)
            }
            if let points = level.minPointsToReach { XCTAssertGreaterThanOrEqual(points, 0) }
        }
        XCTAssertNotNil(tables.remoteTrade)
    }

    func testBundledCostMatchesDiscountFromData() throws {
        let tables = try TradeTables.bundled()
        let base = 12_345 // made-up base cost
        for level in tables.friendshipLevels {
            let expected = Int((Double(base) * (1 - (level.tradingDiscount ?? 0))).rounded(.toNearestOrAwayFromZero))
            XCTAssertEqual(tables.cost(base: base, friendshipLevel: level.level), expected)
            XCTAssertEqual(tables.discount(atLevel: level.level), level.tradingDiscount ?? 0)
            for id in level.unlockedTrading { XCTAssertTrue(tables.isUnlocked(id, atLevel: level.level)) }
        }
    }

    func testEveryBundledCategoryHasAReadableName() throws {
        let tables = try TradeTables.bundled()
        for id in Set(tables.friendshipLevels.flatMap(\.unlockedTrading)) {
            let name = TradeTables.readableCategory(id)
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name.contains("_"), "\(id) -> \(name)")
        }
    }

    // MARK: - Fixture

    func testFixtureDecodesSortsAndKeepsMissingValuesNil() throws {
        let tables = try fixture()
        XCTAssertEqual(tables.friendshipLevels.map(\.level), [0, 1])
        let zero = try XCTUnwrap(tables.level(0))
        XCTAssertNil(zero.minPointsToReach)
        XCTAssertNil(zero.relativePointsToReach)
        XCTAssertNil(zero.raidBallBonus)
        XCTAssertNil(zero.tradingDiscount)
        XCTAssertFalse(zero.unlockedLuckyFriendApplicator)
        XCTAssertEqual(tables.level(1)?.minPointsToReach, 5)
        XCTAssertNil(tables.level(9))
        XCTAssertEqual(tables.remoteTrade?.maxRemoteTradesPerDay, 7)
        XCTAssertNil(tables.remoteTrade?.enabled)
    }

    func testFixtureCostAndUnlocks() throws {
        let tables = try fixture()
        XCTAssertEqual(tables.cost(base: 1000, friendshipLevel: 0), 1000)
        XCTAssertEqual(tables.cost(base: 1000, friendshipLevel: 1), 750)
        // Unknown level: no discount.
        XCTAssertEqual(tables.cost(base: 1000, friendshipLevel: 9), 1000)
        // No base cost entered.
        XCTAssertNil(tables.cost(base: nil, friendshipLevel: 1))
        XCTAssertNil(tables.cost(base: 0, friendshipLevel: 1))
        XCTAssertTrue(tables.isUnlocked("BBB_NON_POKEDEX", atLevel: 1))
        XCTAssertFalse(tables.isUnlocked("BBB_NON_POKEDEX", atLevel: 0))
        XCTAssertFalse(tables.isUnlocked("AAA_IN_POKEDEX", atLevel: 9))
    }

    func testDiscountedCostRoundingAndClamping() {
        XCTAssertEqual(TradeTables.discountedCost(base: 333, discount: 0.5), 167) // 166.5 rounds up
        XCTAssertEqual(TradeTables.discountedCost(base: 101, discount: 0.1), 91)  // 90.9
        XCTAssertEqual(TradeTables.discountedCost(base: 500, discount: 0), 500)
        XCTAssertEqual(TradeTables.discountedCost(base: 500, discount: 1), 0)
        XCTAssertEqual(TradeTables.discountedCost(base: 500, discount: 2), 0)
        XCTAssertEqual(TradeTables.discountedCost(base: 500, discount: -1), 500)
    }

    func testReadableCategory() {
        XCTAssertEqual(TradeTables.readableCategory("REGULAR_IN_POKEDEX"), "Regular, registered")
        XCTAssertEqual(TradeTables.readableCategory("LEGENDARY_NON_POKEDEX"), "Legendary, not registered")
        XCTAssertEqual(TradeTables.readableCategory("GMAX_IN_POKEDEX"), "Gigantamax, registered")
        XCTAssertEqual(TradeTables.readableCategory("SOME_NEW_THING"), "Some new thing")
        XCTAssertEqual(TradeTables.readableCategory("NON_POKEDEX"), "Not registered")
        XCTAssertEqual(TradeTables.readableCategory(""), "")
    }
}
