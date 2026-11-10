import Foundation
@testable import DataSources

/// Tiny, made-up datasets for tests only. They are not real game data.
enum Fixtures {
    static let gamemaster = """
    {"timestamp":"t","pokemon":[
      {"dex":1,"speciesName":"Testmon","speciesId":"testmon","baseStats":{"atk":100,"def":90,"hp":80},
       "types":["grass","none"],"fastMoves":["FAST_A"],"chargedMoves":["CHARGE_B"],"tags":["x"],"released":true},
      {"dex":2,"speciesName":"Othermon","speciesId":"othermon","baseStats":{"atk":110,"def":95,"hp":85},
       "types":["fire","water"]}
    ],"moves":[
      {"moveId":"FAST_A","name":"Fast A","type":"grass","power":3,"energy":0,"energyGain":6,"cooldown":500,"turns":1},
      {"moveId":"CHARGE_B","name":"Charge B","type":"grass","power":90,"energy":50,"energyGain":0,"cooldown":500}
    ]}
    """

    static let events = """
    [{"eventID":"e1","name":"Event One","eventType":"event","heading":"Event",
      "image":"https://example.invalid/x.png","start":"2026-01-01T10:00:00.000","end":"2026-01-01T18:00:00.000Z",
      "extraData":{"generic":{"hasSpawns":true}}},
     {"eventID":"e2","name":"Event Two","eventType":"raid-hour","heading":"Raid Hour","start":null,"end":null,"extraData":null}]
    """

    static let raids = """
    [{"name":"Boss","tier":"5-Star Raids","canBeShiny":true,"types":[{"name":"dragon","image":"x"}],
      "combatPower":{"normal":{"min":1,"max":2},"boosted":{"min":3,"max":4}},"boostedWeather":[{"name":"windy"}]}]
    """

    static let research = """
    [{"text":"<span>Do a thing</span>","type":"catch","rewards":[{"name":"Testmon","canBeShiny":false,"combatPower":{"min":1,"max":2}}]}]
    """

    static let rocketLineups = """
    [{"name":"Leader","title":"Team GO Rocket Leader","type":"",
      "firstPokemon":[{"name":"Testmon","types":["grass"],"isEncounter":false,"canBeShiny":false}],
      "secondPokemon":[],"thirdPokemon":[]}]
    """

    static func json(for id: DataSourceID) -> Data {
        switch id {
        case .gamemaster: return Data(gamemaster.utf8)
        case .events: return Data(events.utf8)
        case .raids: return Data(raids.utf8)
        case .research: return Data(research.utf8)
        case .rocketLineups: return Data(rocketLineups.utf8)
        }
    }

    /// Creates a fresh temporary snapshot folder (all fixtures + manifest) and an empty cache folder.
    static func makeDirectories(snapshotDate: Date) throws -> (snapshots: URL, cache: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tt-tests-\(UUID().uuidString)")
        let snapshots = root.appendingPathComponent("Snapshots")
        let cache = root.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        var manifest: [String: String] = [:]
        let formatter = ISO8601DateFormatter()
        for id in DataSourceID.allCases {
            try json(for: id).write(to: snapshots.appendingPathComponent(id.descriptor.fileName))
            manifest[id.rawValue] = formatter.string(from: snapshotDate)
        }
        try JSONEncoder().encode(manifest).write(to: snapshots.appendingPathComponent("manifest.json"))
        return (snapshots, cache)
    }
}

/// A clock tests can move forward.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}

/// HTTP client that replays queued responses and records requests.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    struct Request: Equatable {
        let url: URL
        let etag: String?
    }

    private let lock = NSLock()
    private var queued: [Result<HTTPResponse, Error>] = []
    private var recorded: [Request] = []

    func enqueue(status: Int, body: Data = Data(), etag: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        queued.append(.success(HTTPResponse(statusCode: status, body: body, etag: etag)))
    }

    func enqueue(error: Error) {
        lock.lock(); defer { lock.unlock() }
        queued.append(.failure(error))
    }

    var requests: [Request] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func get(_ url: URL, ifNoneMatch etag: String?) async throws -> HTTPResponse {
        try take(url: url, etag: etag).get()
    }

    private func take(url: URL, etag: String?) -> Result<HTTPResponse, Error> {
        lock.lock(); defer { lock.unlock() }
        recorded.append(Request(url: url, etag: etag))
        return queued.isEmpty ? .failure(URLError(.notConnectedToInternet)) : queued.removeFirst()
    }
}
