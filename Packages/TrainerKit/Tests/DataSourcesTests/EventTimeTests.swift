import XCTest
@testable import DataSources

final class EventTimeTests: XCTestCase {
    private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    func testLocalTimeIsSameWallClockInEveryZone() throws {
        let time = try XCTUnwrap(EventTime(isoString: "2026-11-16T06:00:00.000"))
        XCTAssertFalse(time.isGlobal)

        var calendar = Calendar(identifier: .gregorian)
        for zone in [amsterdam, newYork] {
            calendar.timeZone = zone
            let date = try XCTUnwrap(time.date(in: zone))
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            XCTAssertEqual(parts.year, 2026)
            XCTAssertEqual(parts.month, 11)
            XCTAssertEqual(parts.day, 16)
            XCTAssertEqual(parts.hour, 6)
            XCTAssertEqual(parts.minute, 0)
        }
        // Different zones -> different instants (Amsterdam is 6 hours ahead of New York in November).
        let difference = try XCTUnwrap(time.date(in: newYork)).timeIntervalSince(try XCTUnwrap(time.date(in: amsterdam)))
        XCTAssertEqual(difference, 6 * 3600)
    }

    func testGlobalTimeIsOneInstant() throws {
        let time = try XCTUnwrap(EventTime(isoString: "2027-02-19T08:00:00.000Z"))
        XCTAssertTrue(time.isGlobal)
        XCTAssertEqual(time.date(in: amsterdam), time.date(in: newYork))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.hour, .minute], from: try XCTUnwrap(time.date(in: amsterdam)))
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 0)
    }

    func testFormatsWithoutFractionalSecondsOrSeconds() {
        XCTAssertNotNil(EventTime(isoString: "2026-11-16T06:00:00"))
        XCTAssertNotNil(EventTime(isoString: "2026-11-16T06:00"))
        XCTAssertNotNil(EventTime(isoString: "2026-11-16T06:00:00Z"))
    }

    func testRejectsGarbage() {
        XCTAssertNil(EventTime(isoString: ""))
        XCTAssertNil(EventTime(isoString: "11/16/2026 06:00"))
        XCTAssertNil(EventTime(isoString: "2026-13-01T06:00:00"))
        XCTAssertNil(EventTime(isoString: "2026-11-16T25:00:00"))
        XCTAssertNil(EventTime(isoString: "nonsenseZ"))
    }

    func testEventModelExposesTimes() throws {
        let events = try JSONDecoder().decode([SDEvent].self, from: Fixtures.json(for: .events))
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].startTime?.isGlobal, false)
        XCTAssertEqual(events[0].endTime?.isGlobal, true)
        XCTAssertNil(events[1].startTime)
        XCTAssertEqual(events[0].extraData?["generic"]?["hasSpawns"], .bool(true))
    }
}
