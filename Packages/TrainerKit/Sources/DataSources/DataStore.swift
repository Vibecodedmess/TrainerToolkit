import Foundation

/// What the app knows about one dataset's local copy.
public struct SourceState: Codable, Sendable, Equatable {
    public enum Origin: String, Codable, Sendable {
        /// The snapshot that ships inside the app.
        case bundled
        /// A copy downloaded from the source and cached on the device.
        case downloaded
        /// Nothing usable. Should never happen, because the snapshot always ships.
        case missing
    }

    public var origin: Origin
    /// When the copy in use was downloaded or last confirmed unchanged by the source.
    public var dataDate: Date?
    /// Last time a network request was made, successful or not.
    public var lastAttempt: Date?
    /// Message from the last failed refresh. Cleared by the next successful one.
    public var lastError: String?
    public var etag: String?
    public var counts: [DatasetCount]

    public init(origin: Origin, dataDate: Date? = nil, lastAttempt: Date? = nil,
                lastError: String? = nil, etag: String? = nil, counts: [DatasetCount] = []) {
        self.origin = origin
        self.dataDate = dataDate
        self.lastAttempt = lastAttempt
        self.lastError = lastError
        self.etag = etag
        self.counts = counts
    }
}

public enum RefreshOutcome: Sendable, Equatable {
    /// New data downloaded, validated and saved.
    case updated
    /// Source says nothing changed (HTTP 304).
    case notModified
    /// Local copy is newer than the refresh interval; no request made.
    case skippedFresh
    /// Source's minimum interval hasn't passed since the last request; no request made.
    case tooSoon(retryAfter: TimeInterval)
    /// Request or validation failed. The previous copy is still in use.
    case failed(String)
}

/// Downloads, validates and caches datasets. Never throws to callers: on any problem it keeps
/// the last good copy and records an error message instead.
public actor DataStore {
    private let cacheDirectory: URL
    private let snapshotDirectory: URL?
    private let http: HTTPClient
    private let now: @Sendable () -> Date
    private var states: [DataSourceID: SourceState] = [:]
    private var prepared = false

    public init(cacheDirectory: URL,
                snapshotDirectory: URL? = BundledSnapshots.directory,
                http: HTTPClient = URLSessionHTTPClient(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.cacheDirectory = cacheDirectory
        self.snapshotDirectory = snapshotDirectory
        self.http = http
        self.now = now
    }

    // MARK: - Reading

    /// Picks the best local copy of every dataset: the cached download, or the bundled
    /// snapshot if there is no valid cache or the snapshot is newer.
    @discardableResult
    public func prepare() -> [DataSourceID: SourceState] {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let saved = loadSavedStates()
        let snapshotDates = snapshotDirectory.map(BundledSnapshots.fetchDates(in:)) ?? [:]

        for id in DataSourceID.allCases {
            var state = saved[id] ?? SourceState(origin: .missing)
            let snapshotDate = snapshotDates[id]

            let cachedCounts = validatedCounts(at: cacheURL(for: id), id: id)
            let cacheIsCurrent = state.origin == .downloaded
                && (snapshotDate == nil || (state.dataDate ?? .distantPast) >= snapshotDate!)

            if let cachedCounts, cacheIsCurrent {
                state.origin = .downloaded
                state.counts = cachedCounts
            } else if let url = snapshotURL(for: id), let counts = validatedCounts(at: url, id: id) {
                state.origin = .bundled
                state.dataDate = snapshotDate
                state.etag = nil // an ETag belongs to a downloaded copy
                state.counts = counts
            } else if let cachedCounts {
                // Snapshot unreadable (shouldn't happen): fall back to whatever cache we have.
                state.origin = .downloaded
                state.counts = cachedCounts
            } else {
                state.origin = .missing
                state.counts = []
                state.lastError = state.lastError ?? "No usable copy of this data"
            }
            states[id] = state
        }
        prepared = true
        saveStates()
        return states
    }

    public func allStates() -> [DataSourceID: SourceState] {
        ensurePrepared()
        return states
    }

    /// Raw JSON of the copy currently in use.
    public func data(for id: DataSourceID) -> Data? {
        ensurePrepared()
        guard let url = currentURL(for: id) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Decoded copy currently in use, or nil if it can't be read.
    public func decoded<T: Decodable>(_ type: T.Type, for id: DataSourceID) -> T? {
        guard let data = data(for: id) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Refreshing

    /// Refreshes every dataset whose copy is older than `maxAge`, one at a time.
    public func refreshIfStale(maxAge: TimeInterval) async -> [DataSourceID: RefreshOutcome] {
        var results: [DataSourceID: RefreshOutcome] = [:]
        for id in DataSourceID.allCases {
            results[id] = await refresh(id, maxAge: maxAge)
        }
        return results
    }

    /// Refreshes every dataset now (still respecting each source's minimum interval).
    public func refreshAll() async -> [DataSourceID: RefreshOutcome] {
        var results: [DataSourceID: RefreshOutcome] = [:]
        for id in DataSourceID.allCases {
            results[id] = await refresh(id, maxAge: nil)
        }
        return results
    }

    /// - Parameter maxAge: skip if the copy is younger than this. `nil` = manual refresh.
    public func refresh(_ id: DataSourceID, maxAge: TimeInterval?) async -> RefreshOutcome {
        ensurePrepared()
        let descriptor = id.descriptor
        let start = now()
        var state = states[id] ?? SourceState(origin: .missing)

        if let maxAge, state.origin != .missing, let dataDate = state.dataDate,
           start.timeIntervalSince(dataDate) < maxAge {
            return .skippedFresh
        }
        if let last = state.lastAttempt {
            let elapsed = start.timeIntervalSince(last)
            if elapsed >= 0, elapsed < descriptor.minimumRefreshInterval {
                return .tooSoon(retryAfter: descriptor.minimumRefreshInterval - elapsed)
            }
        }

        // Record the attempt before awaiting, so a parallel call sees it and backs off.
        state.lastAttempt = start
        states[id] = state
        let sentETag = state.origin == .downloaded ? state.etag : nil

        let outcome: RefreshOutcome
        do {
            let response = try await http.get(descriptor.remoteURL, ifNoneMatch: sentETag)
            state = states[id] ?? state
            switch response.statusCode {
            case 304 where sentETag != nil:
                state.dataDate = now()
                state.lastError = nil
                outcome = .notModified
            case 200..<300:
                let counts = try DatasetValidator.validate(response.body, for: id)
                try response.body.write(to: cacheURL(for: id), options: .atomic)
                state.origin = .downloaded
                state.dataDate = now()
                state.etag = response.etag
                state.counts = counts
                state.lastError = nil
                outcome = .updated
            default:
                throw DatasetValidationError(message: "Server answered HTTP \(response.statusCode)")
            }
        } catch {
            state = states[id] ?? state
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state.lastError = message
            outcome = .failed(message)
        }
        states[id] = state
        saveStates()
        return outcome
    }

    // MARK: - Files

    private func ensurePrepared() {
        if !prepared { prepare() }
    }

    private func cacheURL(for id: DataSourceID) -> URL {
        cacheDirectory.appendingPathComponent(id.descriptor.fileName)
    }

    private func snapshotURL(for id: DataSourceID) -> URL? {
        snapshotDirectory?.appendingPathComponent(id.descriptor.fileName)
    }

    private func currentURL(for id: DataSourceID) -> URL? {
        switch states[id]?.origin {
        case .downloaded: return cacheURL(for: id)
        case .bundled: return snapshotURL(for: id)
        case .missing, .none: return nil
        }
    }

    private func validatedCounts(at url: URL, id: DataSourceID) -> [DatasetCount]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? DatasetValidator.validate(data, for: id)
    }

    private var stateFileURL: URL { cacheDirectory.appendingPathComponent("state.json") }

    private func loadSavedStates() -> [DataSourceID: SourceState] {
        guard let data = try? Data(contentsOf: stateFileURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let raw = try? decoder.decode([String: SourceState].self, from: data) else { return [:] }
        var result: [DataSourceID: SourceState] = [:]
        for (key, value) in raw {
            if let id = DataSourceID(rawValue: key) { result[id] = value }
        }
        return result
    }

    private func saveStates() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let raw = Dictionary(uniqueKeysWithValues: states.map { ($0.key.rawValue, $0.value) })
        if let data = try? encoder.encode(raw) {
            try? data.write(to: stateFileURL, options: .atomic)
        }
    }
}
