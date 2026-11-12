import Foundation

/// Everything the trainer created in the app, as one JSON file. Plain values only, so the format
/// doesn't depend on SwiftData; the app maps its models to and from these.
public struct AppBackup: Codable, Sendable, Equatable {
    public static let formatName = "trainer-toolkit-backup"
    public static let currentVersion = 1

    public struct Collected: Codable, Sendable, Equatable {
        public var speciesId: String
        public var speciesName: String
        public var nickname: String
        public var baseAttack: Int
        public var baseDefense: Int
        public var baseStamina: Int
        public var ivAttack: Int
        public var ivDefense: Int
        public var ivStamina: Int
        public var levelHalfSteps: Int
        public var fastMoveId: String
        public var chargedMoveId: String
        public var secondChargedMoveId: String
        public var isShadow: Bool
        public var isPurified: Bool
        public var isShiny: Bool
        public var isLucky: Bool
        public var notes: String
        public var source: String
        public var createdAt: Date
        public var updatedAt: Date

        public init(speciesId: String, speciesName: String, nickname: String, baseAttack: Int, baseDefense: Int,
                    baseStamina: Int, ivAttack: Int, ivDefense: Int, ivStamina: Int, levelHalfSteps: Int,
                    fastMoveId: String, chargedMoveId: String, secondChargedMoveId: String, isShadow: Bool,
                    isPurified: Bool, isShiny: Bool, isLucky: Bool, notes: String, source: String,
                    createdAt: Date, updatedAt: Date) {
            self.speciesId = speciesId; self.speciesName = speciesName; self.nickname = nickname
            self.baseAttack = baseAttack; self.baseDefense = baseDefense; self.baseStamina = baseStamina
            self.ivAttack = ivAttack; self.ivDefense = ivDefense; self.ivStamina = ivStamina
            self.levelHalfSteps = levelHalfSteps; self.fastMoveId = fastMoveId; self.chargedMoveId = chargedMoveId
            self.secondChargedMoveId = secondChargedMoveId; self.isShadow = isShadow; self.isPurified = isPurified
            self.isShiny = isShiny; self.isLucky = isLucky; self.notes = notes; self.source = source
            self.createdAt = createdAt; self.updatedAt = updatedAt
        }
    }

    public struct Goal: Codable, Sendable, Equatable {
        public var speciesId: String
        public var speciesName: String
        public var baseAttack: Int
        public var baseDefense: Int
        public var baseStamina: Int
        public var ivAttack: Int
        public var ivDefense: Int
        public var ivStamina: Int
        public var currentLevelHalfSteps: Int
        public var targetLevelHalfSteps: Int
        public var isShadow: Bool
        public var isPurified: Bool
        public var isLucky: Bool
        public var isBestBuddy: Bool
        public var candyOwned: Int
        public var xlCandyOwned: Int
        public var candyIncome: Double
        public var xlCandyIncome: Double
        public var incomeIsPerWeek: Bool
        public var createdAt: Date

        public init(speciesId: String, speciesName: String, baseAttack: Int, baseDefense: Int, baseStamina: Int,
                    ivAttack: Int, ivDefense: Int, ivStamina: Int, currentLevelHalfSteps: Int, targetLevelHalfSteps: Int,
                    isShadow: Bool, isPurified: Bool, isLucky: Bool, isBestBuddy: Bool, candyOwned: Int,
                    xlCandyOwned: Int, candyIncome: Double, xlCandyIncome: Double, incomeIsPerWeek: Bool, createdAt: Date) {
            self.speciesId = speciesId; self.speciesName = speciesName
            self.baseAttack = baseAttack; self.baseDefense = baseDefense; self.baseStamina = baseStamina
            self.ivAttack = ivAttack; self.ivDefense = ivDefense; self.ivStamina = ivStamina
            self.currentLevelHalfSteps = currentLevelHalfSteps; self.targetLevelHalfSteps = targetLevelHalfSteps
            self.isShadow = isShadow; self.isPurified = isPurified; self.isLucky = isLucky; self.isBestBuddy = isBestBuddy
            self.candyOwned = candyOwned; self.xlCandyOwned = xlCandyOwned; self.candyIncome = candyIncome
            self.xlCandyIncome = xlCandyIncome; self.incomeIsPerWeek = incomeIsPerWeek; self.createdAt = createdAt
        }
    }

    public struct EventPlan: Codable, Sendable, Equatable {
        public var eventID: String
        public var eventName: String
        public var exclusiveMove: String
        public var evolveDeadline: Date?
        public var remindBeforeStart: Bool
        public var remindBeforeDeadline: Bool
        public var reminderLeadMinutes: Int

        public init(eventID: String, eventName: String, exclusiveMove: String, evolveDeadline: Date?,
                    remindBeforeStart: Bool, remindBeforeDeadline: Bool, reminderLeadMinutes: Int) {
            self.eventID = eventID; self.eventName = eventName; self.exclusiveMove = exclusiveMove
            self.evolveDeadline = evolveDeadline; self.remindBeforeStart = remindBeforeStart
            self.remindBeforeDeadline = remindBeforeDeadline; self.reminderLeadMinutes = reminderLeadMinutes
        }
    }

    public struct ChecklistItem: Codable, Sendable, Equatable {
        public var eventID: String
        public var text: String
        public var isDone: Bool
        public var order: Int
        public var createdAt: Date

        public init(eventID: String, text: String, isDone: Bool, order: Int, createdAt: Date) {
            self.eventID = eventID; self.text = text; self.isDone = isDone; self.order = order; self.createdAt = createdAt
        }
    }

    public struct SearchPreset: Codable, Sendable, Equatable {
        public var name: String
        /// The saved search's own JSON (SearchState), kept as-is.
        public var stateData: Data
        public var createdAt: Date

        public init(name: String, stateData: Data, createdAt: Date) {
            self.name = name; self.stateData = stateData; self.createdAt = createdAt
        }
    }

    public struct TradeWant: Codable, Sendable, Equatable {
        public var theyWant: Bool
        public var speciesId: String
        public var speciesName: String
        public var note: String
        public var isShiny: Bool
        public var isDone: Bool
        public var createdAt: Date

        public init(theyWant: Bool, speciesId: String, speciesName: String, note: String, isShiny: Bool,
                    isDone: Bool, createdAt: Date) {
            self.theyWant = theyWant; self.speciesId = speciesId; self.speciesName = speciesName; self.note = note
            self.isShiny = isShiny; self.isDone = isDone; self.createdAt = createdAt
        }
    }

    public struct TradeFriend: Codable, Sendable, Equatable {
        public var name: String
        public var friendshipLevel: Int
        public var isLuckyFriend: Bool
        public var notes: String
        public var nextLevelDate: Date?
        public var createdAt: Date
        public var wants: [TradeWant]

        public init(name: String, friendshipLevel: Int, isLuckyFriend: Bool, notes: String, nextLevelDate: Date?,
                    createdAt: Date, wants: [TradeWant]) {
            self.name = name; self.friendshipLevel = friendshipLevel; self.isLuckyFriend = isLuckyFriend
            self.notes = notes; self.nextLevelDate = nextLevelDate; self.createdAt = createdAt; self.wants = wants
        }
    }

    public var format: String
    public var version: Int
    public var createdAt: Date
    public var appVersion: String
    public var collection: [Collected]
    public var goals: [Goal]
    public var eventPlans: [EventPlan]
    public var checklist: [ChecklistItem]
    public var searchPresets: [SearchPreset]
    public var tradeFriends: [TradeFriend]
    /// User-entered numbers kept in the app's settings (for example base trade costs), by settings key.
    public var settings: [String: Int]

    public init(createdAt: Date, appVersion: String, collection: [Collected] = [], goals: [Goal] = [],
                eventPlans: [EventPlan] = [], checklist: [ChecklistItem] = [], searchPresets: [SearchPreset] = [],
                tradeFriends: [TradeFriend] = [], settings: [String: Int] = [:]) {
        format = Self.formatName
        version = Self.currentVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.collection = collection
        self.goals = goals
        self.eventPlans = eventPlans
        self.checklist = checklist
        self.searchPresets = searchPresets
        self.tradeFriends = tradeFriends
        self.settings = settings
    }

    // MARK: - File

    public enum BackupError: LocalizedError, Equatable {
        case notABackup
        case newerVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .notABackup: return "This file isn't a Trainer Toolkit backup."
            case .newerVersion(let v): return "This backup was made by a newer version of the app (format \(v)). Update the app first."
            }
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> AppBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Check the header first, so a newer format gives a clear message rather than a decoding error.
        struct Header: Decodable { let format: String?; let version: Int? }
        guard let header = try? decoder.decode(Header.self, from: data), header.format == formatName,
              let version = header.version else { throw BackupError.notABackup }
        guard version <= currentVersion else { throw BackupError.newerVersion(version) }
        return try decoder.decode(AppBackup.self, from: data)
    }

    /// "12 Pokémon, 3 goals, …" for a preview before restoring.
    public var summary: [(label: String, count: Int)] {
        [("Pokémon in My Collection", collection.count), ("Planner goals", goals.count),
         ("Event plans", eventPlans.count), ("Checklist items", checklist.count),
         ("Saved searches", searchPresets.count), ("Trade friends", tradeFriends.count),
         ("Want list entries", tradeFriends.reduce(0) { $0 + $1.wants.count })]
    }

    public var isEmpty: Bool {
        collection.isEmpty && goals.isEmpty && eventPlans.isEmpty && checklist.isEmpty && searchPresets.isEmpty
            && tradeFriends.isEmpty && settings.isEmpty
    }

    /// File name for a backup made at `date`, e.g. "TrainerToolkit-backup-2026-11-12-0930.json".
    public static func fileName(for date: Date, prefix: String = "TrainerToolkit-backup", timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "\(prefix)-\(f.string(from: date)).json"
    }

    /// Which automatic backups to delete so only the newest `keep` remain (names sort by date).
    public static func filesToPrune(_ names: [String], prefix: String = "TrainerToolkit-backup", keep: Int) -> [String] {
        let backups = names.filter { $0.hasPrefix(prefix + "-") && $0.hasSuffix(".json") }.sorted(by: >)
        return Array(backups.dropFirst(max(keep, 0)))
    }
}
