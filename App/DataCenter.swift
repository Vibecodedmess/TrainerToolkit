import Foundation
import Observation
import DataSources

/// User-adjustable data settings. Kept outside `DataCenter` so views can use them anywhere.
enum DataSettings {
    static let refreshIntervalKey = "data.refreshIntervalHours"
    static let defaultRefreshHours = 6
    static let refreshChoices = [3, 6, 12, 24]

    static var refreshInterval: TimeInterval {
        let hours = UserDefaults.standard.integer(forKey: refreshIntervalKey)
        return TimeInterval((hours > 0 ? hours : defaultRefreshHours) * 3600)
    }
}

/// App-wide access to the community datasets. Wraps `DataStore` for SwiftUI.
@MainActor
@Observable
final class DataCenter {
    struct SourceRow: Identifiable {
        let descriptor: DataSourceDescriptor
        let state: SourceState
        var id: DataSourceID { descriptor.id }
    }

    private(set) var rows: [SourceRow] = []
    /// Decoded Pokémon & moves currently in use. Nil only until the first load finishes.
    private(set) var gamemaster: Gamemaster?
    /// Pokémon that can be picked in the Planner (see `Gamemaster.powerUpCandidates`).
    private(set) var powerUpCandidates: [GMPokemon] = []
    /// Name / evolution lookups on the gamemaster.
    private(set) var lookup: GamemasterLookup?
    private var gamemasterDate: Date?
    /// Events from the feed currently in use (entries in an unexpected format are skipped).
    private(set) var events: [SDEvent] = []
    private var eventsDate: Date?
    /// Current raid bosses from the feed in use.
    private(set) var raids: [SDRaidBoss] = []
    private var raidsDate: Date?
    /// Team GO Rocket lineups from the feed in use.
    private(set) var rocketLineups: [SDRocketLineup] = []
    private var rocketDate: Date?
    private(set) var isRefreshing = false
    /// Result of the last manual refresh, shown under the Refresh now button.
    private(set) var lastRunMessage: String?
    let store: DataStore

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        store = DataStore(cacheDirectory: base.appendingPathComponent("DataCache", isDirectory: true))
    }

    /// Non-blocking warning text when any source failed to update, else nil.
    var warning: String? {
        let failing = rows.filter { $0.state.lastError != nil || $0.state.origin == .missing }
        switch failing.count {
        case 0: return nil
        case 1: return "\(failing[0].descriptor.displayName) couldn't update. Using the last saved copy."
        default: return "\(failing.count) data sources couldn't update. Using the last saved copies."
        }
    }

    /// Called once at launch: load local copies, then refresh anything stale in the background.
    func start() async {
        _ = await store.prepare()
        await reload()
        await refreshIfStale()
    }

    /// Called when the app comes to the foreground.
    func refreshIfStale() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        _ = await store.refreshIfStale(maxAge: DataSettings.refreshInterval)
        await reload()
        isRefreshing = false
    }

    /// The "Refresh now" button.
    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let outcomes = await store.refreshAll()
        await reload()
        lastRunMessage = Self.summary(of: outcomes)
        isRefreshing = false
    }

    private func reload() async {
        let states = await store.allStates()
        rows = DataSourceID.allCases.map {
            SourceRow(descriptor: $0.descriptor, state: states[$0] ?? SourceState(origin: .missing))
        }
        // Re-decode the gamemaster only when the copy in use changed.
        let gmState = states[.gamemaster]
        if gamemaster == nil || gmState?.dataDate != gamemasterDate {
            if let decoded = await store.decoded(Gamemaster.self, for: .gamemaster) {
                gamemaster = decoded
                powerUpCandidates = decoded.powerUpCandidates
                lookup = GamemasterLookup(decoded)
                gamemasterDate = gmState?.dataDate
            }
        }
        let eventsState = states[.events]
        if events.isEmpty || eventsState?.dataDate != eventsDate {
            if let decoded = await store.decoded(LossyArray<SDEvent>.self, for: .events) {
                events = decoded.elements
                eventsDate = eventsState?.dataDate
            }
        }
        let raidsState = states[.raids]
        if raids.isEmpty || raidsState?.dataDate != raidsDate {
            if let decoded = await store.decoded(LossyArray<SDRaidBoss>.self, for: .raids) {
                raids = decoded.elements
                raidsDate = raidsState?.dataDate
            }
        }
        let rocketState = states[.rocketLineups]
        if rocketLineups.isEmpty || rocketState?.dataDate != rocketDate {
            if let decoded = await store.decoded(LossyArray<SDRocketLineup>.self, for: .rocketLineups) {
                rocketLineups = decoded.elements
                rocketDate = rocketState?.dataDate
            }
        }
    }

    static func summary(of outcomes: [DataSourceID: RefreshOutcome]) -> String {
        var updated = 0, unchanged = 0, failed = 0
        var waitSeconds: TimeInterval = 0
        for outcome in outcomes.values {
            switch outcome {
            case .updated: updated += 1
            case .notModified, .skippedFresh: unchanged += 1
            case .failed: failed += 1
            case .tooSoon(let retryAfter): waitSeconds = max(waitSeconds, retryAfter)
            }
        }
        var parts: [String] = []
        if updated > 0 { parts.append("\(updated) updated") }
        if unchanged > 0 { parts.append("\(unchanged) unchanged") }
        if failed > 0 { parts.append("\(failed) failed") }
        if waitSeconds > 0 {
            let minutes = Int((waitSeconds / 60).rounded(.up))
            parts.append("some were checked moments ago, try again in \(minutes) min")
        }
        guard !parts.isEmpty else { return "Nothing to refresh." }
        let text = parts.joined(separator: ", ")
        return text.prefix(1).uppercased() + String(text.dropFirst()) + "."
    }
}
