import XCTest
@testable import Counters
import DataSources

/// Checks the extracted lines against the bundled Rocket feed; search tests use made-up text.
final class RocketQuotesTests: XCTestCase {
    private var quotes: RocketQuotes!
    private var lineups: [SDRocketLineup] = []

    override func setUpWithError() throws {
        quotes = try RocketQuotes.bundled()
        let dir = try XCTUnwrap(BundledSnapshots.directory)
        lineups = try JSONDecoder().decode(LossyArray<SDRocketLineup>.self,
                                           from: Data(contentsOf: dir.appendingPathComponent("rocketLineups.json"))).elements
    }

    func testEveryTypedGruntInTheFeedHasItsLine() {
        let typed = lineups.filter { !($0.type ?? "").isEmpty }
        XCTAssertFalse(typed.isEmpty)
        for l in typed {
            let lines = quotes.lines(name: l.name, type: l.type, title: l.title)
            XCTAssertEqual(lines.count, 1, l.name)
            XCTAssertEqual(lines.first, quotes.typed[(l.type ?? "").lowercased()], l.name)
        }
    }

    func testLeadersGenericGruntsAndDecoys() {
        for (leader, line) in quotes.leaders {
            XCTAssertEqual(quotes.lines(name: leader.capitalized, type: "", title: "Team GO Rocket Leader"), [line])
        }
        XCTAssertFalse(quotes.generic.isEmpty)
        XCTAssertEqual(quotes.lines(name: "Female Grunt", type: "", title: "Team GO Rocket Grunt"), quotes.generic)
        XCTAssertEqual(quotes.lines(name: "Decoy Female Grunt", type: "", title: "Team GO Rocket Grunt"), [])
        XCTAssertEqual(quotes.lines(name: "Someone Else", type: nil, title: nil), [])
        // Every leader and the boss in the feed is covered.
        for l in lineups where (l.title ?? "").contains("Leader") || (l.title ?? "").contains("Boss") {
            XCTAssertFalse(quotes.lines(name: l.name, type: l.type, title: l.title).isEmpty, l.name)
        }
    }

    func testNormalizeAndMatch() {
        XCTAssertEqual(RocketQuotes.normalize("Don’t STOP—now... “Okay”!"), "dont stop now okay")
        XCTAssertTrue(RocketQuotes.matches("dont stop", in: "Don’t stop now!"))
        XCTAssertTrue(RocketQuotes.matches("don't   STOP", in: "Don’t stop now!"))
        XCTAssertTrue(RocketQuotes.matches("now dont", in: "Don’t stop now!"))
        XCTAssertTrue(RocketQuotes.matches("", in: "anything"))
        XCTAssertFalse(RocketQuotes.matches("go", in: "Don’t stop now!"))
        XCTAssertTrue(RocketQuotes.matches("pokemon", in: "My Pokémon"))
    }
}
