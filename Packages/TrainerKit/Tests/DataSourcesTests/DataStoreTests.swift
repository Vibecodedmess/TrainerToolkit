import XCTest
@testable import DataSources

final class DataStoreTests: XCTestCase {
    private let snapshotDate = Date(timeIntervalSince1970: 1_800_000_000)
    private var clock: TestClock!
    private var http: MockHTTPClient!
    private var dirs: (snapshots: URL, cache: URL)!

    override func setUpWithError() throws {
        clock = TestClock(snapshotDate.addingTimeInterval(24 * 3600))
        http = MockHTTPClient()
        dirs = try Fixtures.makeDirectories(snapshotDate: snapshotDate)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dirs.snapshots.deletingLastPathComponent())
    }

    private func makeStore() -> DataStore {
        let clock: TestClock = self.clock
        let client: MockHTTPClient = http
        return DataStore(cacheDirectory: dirs.cache, snapshotDirectory: dirs.snapshots, http: client, now: { clock.now })
    }

    func testFirstLaunchUsesBundledSnapshots() async {
        let states = await makeStore().prepare()
        XCTAssertEqual(states.count, DataSourceID.allCases.count)
        for (_, state) in states {
            XCTAssertEqual(state.origin, .bundled)
            XCTAssertEqual(state.dataDate, snapshotDate)
            XCTAssertFalse(state.counts.isEmpty)
        }
        XCTAssertTrue(http.requests.isEmpty, "prepare must not touch the network")
    }

    func testSuccessfulRefreshCachesNewData() async {
        let store = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .raids), etag: "\"v1\"")
        let outcome = await store.refresh(.raids, maxAge: nil)
        XCTAssertEqual(outcome, .updated)

        let state = await store.allStates()[.raids]
        XCTAssertEqual(state?.origin, .downloaded)
        XCTAssertEqual(state?.etag, "\"v1\"")
        XCTAssertEqual(state?.dataDate, clock.now)
        XCTAssertNil(state?.lastError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dirs.cache.appendingPathComponent("raids.json").path))
    }

    func testBrokenDownloadKeepsLastGoodCopy() async {
        let store = makeStore()
        http.enqueue(status: 200, body: Data(#"{"totally":"different"}"#.utf8))
        let outcome = await store.refresh(.events, maxAge: nil)
        guard case .failed = outcome else { return XCTFail("expected failure, got \(outcome)") }

        let state = await store.allStates()[.events]
        XCTAssertEqual(state?.origin, .bundled)
        XCTAssertNotNil(state?.lastError)
        let data = await store.data(for: .events)
        XCTAssertEqual(data, Fixtures.json(for: .events))
    }

    func testNetworkErrorAndHTTPErrorKeepData() async {
        let store = makeStore()
        http.enqueue(error: URLError(.timedOut))
        let first = await store.refresh(.research, maxAge: nil)
        guard case .failed = first else { return XCTFail("got \(first)") }

        clock.advance(by: 600)
        http.enqueue(status: 500)
        let second = await store.refresh(.research, maxAge: nil)
        guard case .failed(let message) = second else { return XCTFail("got \(second)") }
        XCTAssertTrue(message.contains("500"))
        let state = await store.allStates()[.research]
        XCTAssertEqual(state?.origin, .bundled)
        XCTAssertFalse(state?.counts.isEmpty ?? true)
    }

    func testNotModifiedSendsETagAndUpdatesDate() async {
        let store = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .raids), etag: "\"v1\"")
        _ = await store.refresh(.raids, maxAge: nil)

        clock.advance(by: 3600)
        http.enqueue(status: 304)
        let outcome = await store.refresh(.raids, maxAge: nil)
        XCTAssertEqual(outcome, .notModified)
        XCTAssertEqual(http.requests.last?.etag, "\"v1\"")
        let state = await store.allStates()[.raids]
        XCTAssertEqual(state?.dataDate, clock.now)
        XCTAssertEqual(state?.origin, .downloaded)
    }

    func testBundledCopyNeverSendsETag() async {
        let store = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .raids))
        _ = await store.refresh(.raids, maxAge: nil)
        XCTAssertNil(http.requests.first?.etag)
    }

    func testRespectsSourceMinimumInterval() async {
        let store = makeStore()
        http.enqueue(error: URLError(.timedOut))
        _ = await store.refresh(.events, maxAge: nil)

        clock.advance(by: 60)
        let outcome = await store.refresh(.events, maxAge: nil)
        guard case .tooSoon(let retryAfter) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertEqual(retryAfter, 4 * 60, accuracy: 0.001)
        XCTAssertEqual(http.requests.count, 1, "no second request inside the minimum interval")
    }

    func testSkipsWhenYoungerThanMaxAge() async {
        let store = makeStore()
        // Snapshot is 24 h old: with a 48 h max age it is still fresh.
        let fresh = await store.refresh(.gamemaster, maxAge: 48 * 3600)
        XCTAssertEqual(fresh, .skippedFresh)
        XCTAssertTrue(http.requests.isEmpty)

        // With a 6 h max age it is stale and gets fetched.
        http.enqueue(status: 200, body: Fixtures.json(for: .gamemaster))
        let stale = await store.refresh(.gamemaster, maxAge: 6 * 3600)
        XCTAssertEqual(stale, .updated)
    }

    func testRefreshIfStaleCoversEverySource() async {
        let store = makeStore()
        for id in DataSourceID.allCases {
            http.enqueue(status: 200, body: Fixtures.json(for: id))
        }
        let results = await store.refreshIfStale(maxAge: 3600)
        XCTAssertEqual(results.count, DataSourceID.allCases.count)
        XCTAssertTrue(results.values.allSatisfy { $0 == .updated })
    }

    func testStatePersistsAcrossLaunches() async {
        let first = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .raids), etag: "\"v9\"")
        _ = await first.refresh(.raids, maxAge: nil)

        let second = makeStore()
        let state = await second.prepare()[.raids]
        XCTAssertEqual(state?.origin, .downloaded)
        XCTAssertEqual(state?.etag, "\"v9\"")
        XCTAssertNotNil(state?.lastAttempt)
    }

    func testNewerBundledSnapshotWinsOverOlderCache() async throws {
        let first = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .raids))
        _ = await first.refresh(.raids, maxAge: nil)

        // Simulate an app update that ships a snapshot newer than the cached download.
        let newer = clock.now.addingTimeInterval(3600)
        let manifest = DataSourceID.allCases.reduce(into: [String: String]()) {
            $0[$1.rawValue] = ISO8601DateFormatter().string(from: newer)
        }
        try JSONEncoder().encode(manifest).write(to: dirs.snapshots.appendingPathComponent("manifest.json"))

        let state = await makeStore().prepare()[.raids]
        XCTAssertEqual(state?.origin, .bundled)
        XCTAssertNil(state?.etag)
    }

    func testCorruptCacheFallsBackToSnapshot() async throws {
        let first = makeStore()
        http.enqueue(status: 200, body: Fixtures.json(for: .events))
        _ = await first.refresh(.events, maxAge: nil)
        try Data("garbage".utf8).write(to: dirs.cache.appendingPathComponent("events.json"))

        let state = await makeStore().prepare()[.events]
        XCTAssertEqual(state?.origin, .bundled)
    }
}
