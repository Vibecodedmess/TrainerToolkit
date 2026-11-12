import Foundation
import SwiftData
import SearchBuilder
import BackupFormat

/// Backups of everything the trainer created: to a file they pick (Files, iCloud Drive), and
/// automatically, at most once a day, to a folder they chose once.
///
/// Free-signed (sideloaded) apps can't use CloudKit/iCloud containers, so iCloud is reached the
/// same way as any other place: through the Files picker and a security-scoped folder bookmark.
@MainActor
enum BackupManager {
    /// Whole-number settings that hold user-entered data (not display preferences).
    static let settingsKeys = [
        "trades.baseCost.regularRegistered", "trades.baseCost.regularNotRegistered",
        "trades.baseCost.specialRegistered", "trades.baseCost.specialNotRegistered",
        DataSettings.refreshIntervalKey,
    ]

    private static let folderBookmarkKey = "backup.folderBookmark"
    private static let folderNameKey = "backup.folderName"
    private static let lastBackupKey = "backup.lastBackup"
    private static let lastAutoKey = "backup.lastAutoBackup"
    private static let lastErrorKey = "backup.lastAutoError"
    static let autoEnabledKey = "backup.autoEnabled"
    static let keepCount = 14
    static let autoInterval: TimeInterval = 24 * 3600

    // MARK: - State

    static var lastBackup: Date? { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
    static var folderName: String? { UserDefaults.standard.string(forKey: folderNameKey) }
    static var lastAutoError: String? { UserDefaults.standard.string(forKey: lastErrorKey) }
    static var hasFolder: Bool { UserDefaults.standard.data(forKey: folderBookmarkKey) != nil }
    static var autoEnabled: Bool { UserDefaults.standard.bool(forKey: autoEnabledKey) }

    static func markBackedUp(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastBackupKey)
    }

    // MARK: - Snapshot

    static func snapshot(_ context: ModelContext) throws -> AppBackup {
        let collection = try context.fetch(FetchDescriptor<CollectedPokemon>()).map { p in
            AppBackup.Collected(speciesId: p.speciesId, speciesName: p.speciesName, nickname: p.nickname,
                                baseAttack: p.baseAttack, baseDefense: p.baseDefense, baseStamina: p.baseStamina,
                                ivAttack: p.ivAttack, ivDefense: p.ivDefense, ivStamina: p.ivStamina,
                                levelHalfSteps: p.levelHalfSteps, fastMoveId: p.fastMoveId, chargedMoveId: p.chargedMoveId,
                                secondChargedMoveId: p.secondChargedMoveId, isShadow: p.isShadow, isPurified: p.isPurified,
                                isShiny: p.isShiny, isLucky: p.isLucky, notes: p.notes, source: p.source,
                                createdAt: p.createdAt, updatedAt: p.updatedAt)
        }
        let goals = try context.fetch(FetchDescriptor<PowerUpGoal>()).map { g in
            AppBackup.Goal(speciesId: g.speciesId, speciesName: g.speciesName, baseAttack: g.baseAttack,
                           baseDefense: g.baseDefense, baseStamina: g.baseStamina, ivAttack: g.ivAttack,
                           ivDefense: g.ivDefense, ivStamina: g.ivStamina, currentLevelHalfSteps: g.currentLevelHalfSteps,
                           targetLevelHalfSteps: g.targetLevelHalfSteps, isShadow: g.isShadow, isPurified: g.isPurified,
                           isLucky: g.isLucky, isBestBuddy: g.isBestBuddy, candyOwned: g.candyOwned,
                           xlCandyOwned: g.xlCandyOwned, candyIncome: g.candyIncome, xlCandyIncome: g.xlCandyIncome,
                           incomeIsPerWeek: g.incomeIsPerWeek, createdAt: g.createdAt)
        }
        let plans = try context.fetch(FetchDescriptor<EventPlan>()).map { e in
            AppBackup.EventPlan(eventID: e.eventID, eventName: e.eventName, exclusiveMove: e.exclusiveMove,
                                evolveDeadline: e.evolveDeadline, remindBeforeStart: e.remindBeforeStart,
                                remindBeforeDeadline: e.remindBeforeDeadline, reminderLeadMinutes: e.reminderLeadMinutes)
        }
        let checklist = try context.fetch(FetchDescriptor<ChecklistItem>()).map { c in
            AppBackup.ChecklistItem(eventID: c.eventID, text: c.text, isDone: c.isDone, order: c.order, createdAt: c.createdAt)
        }
        let presets = try context.fetch(FetchDescriptor<SavedSearchPreset>()).map { s in
            AppBackup.SearchPreset(name: s.name, stateData: s.stateData, createdAt: s.createdAt)
        }
        let friends = try context.fetch(FetchDescriptor<TradeFriend>()).map { f in
            AppBackup.TradeFriend(name: f.name, friendshipLevel: f.friendshipLevel, isLuckyFriend: f.isLuckyFriend,
                                  notes: f.notes, nextLevelDate: f.nextLevelDate, createdAt: f.createdAt,
                                  wants: f.wants.map { w in
                                      AppBackup.TradeWant(theyWant: w.theyWant, speciesId: w.speciesId,
                                                          speciesName: w.speciesName, note: w.note, isShiny: w.isShiny,
                                                          isDone: w.isDone, createdAt: w.createdAt)
                                  })
        }
        var settings: [String: Int] = [:]
        for key in settingsKeys where UserDefaults.standard.object(forKey: key) != nil {
            settings[key] = UserDefaults.standard.integer(forKey: key)
        }
        return AppBackup(createdAt: .now, appVersion: InstallInfo.versionString, collection: collection, goals: goals,
                         eventPlans: plans, checklist: checklist, searchPresets: presets, tradeFriends: friends,
                         settings: settings)
    }

    // MARK: - Restore

    /// Replaces all user data with the backup. The current data is saved first (see `undoAvailable`).
    static func restore(_ backup: AppBackup, into context: ModelContext) throws {
        try saveUndoCopy(context)
        try context.delete(model: TradeWant.self)
        try context.delete(model: TradeFriend.self)
        try context.delete(model: CollectedPokemon.self)
        try context.delete(model: PowerUpGoal.self)
        try context.delete(model: ChecklistItem.self)
        try context.delete(model: EventPlan.self)
        try context.delete(model: SavedSearchPreset.self)
        try context.save()

        for c in backup.collection {
            let p = CollectedPokemon(speciesId: c.speciesId, speciesName: c.speciesName, baseAttack: c.baseAttack,
                                     baseDefense: c.baseDefense, baseStamina: c.baseStamina,
                                     levelHalfSteps: c.levelHalfSteps, source: c.source)
            p.nickname = c.nickname
            p.ivAttack = c.ivAttack
            p.ivDefense = c.ivDefense
            p.ivStamina = c.ivStamina
            p.fastMoveId = c.fastMoveId
            p.chargedMoveId = c.chargedMoveId
            p.secondChargedMoveId = c.secondChargedMoveId
            p.isShadow = c.isShadow
            p.isPurified = c.isPurified
            p.isShiny = c.isShiny
            p.isLucky = c.isLucky
            p.notes = c.notes
            p.createdAt = c.createdAt
            p.updatedAt = c.updatedAt
            context.insert(p)
        }
        for g in backup.goals {
            context.insert(PowerUpGoal(
                speciesId: g.speciesId, speciesName: g.speciesName, baseAttack: g.baseAttack, baseDefense: g.baseDefense,
                baseStamina: g.baseStamina, ivAttack: g.ivAttack, ivDefense: g.ivDefense, ivStamina: g.ivStamina,
                currentLevelHalfSteps: g.currentLevelHalfSteps, targetLevelHalfSteps: g.targetLevelHalfSteps,
                isShadow: g.isShadow, isPurified: g.isPurified, isLucky: g.isLucky, isBestBuddy: g.isBestBuddy,
                candyOwned: g.candyOwned, xlCandyOwned: g.xlCandyOwned, candyIncome: g.candyIncome,
                xlCandyIncome: g.xlCandyIncome, incomeIsPerWeek: g.incomeIsPerWeek, createdAt: g.createdAt))
        }
        var seenEvents: Set<String> = []
        for e in backup.eventPlans where seenEvents.insert(e.eventID).inserted {
            let plan = EventPlan(eventID: e.eventID, eventName: e.eventName)
            plan.exclusiveMove = e.exclusiveMove
            plan.evolveDeadline = e.evolveDeadline
            plan.remindBeforeStart = e.remindBeforeStart
            plan.remindBeforeDeadline = e.remindBeforeDeadline
            plan.reminderLeadMinutes = e.reminderLeadMinutes
            context.insert(plan)
        }
        for c in backup.checklist {
            let item = ChecklistItem(eventID: c.eventID, text: c.text, order: c.order)
            item.isDone = c.isDone
            item.createdAt = c.createdAt
            context.insert(item)
        }
        for s in backup.searchPresets {
            let preset = SavedSearchPreset(name: s.name, state: SearchState(), createdAt: s.createdAt)
            preset.stateData = s.stateData
            context.insert(preset)
        }
        for f in backup.tradeFriends {
            let friend = TradeFriend(name: f.name, friendshipLevel: f.friendshipLevel)
            friend.isLuckyFriend = f.isLuckyFriend
            friend.notes = f.notes
            friend.nextLevelDate = f.nextLevelDate
            friend.createdAt = f.createdAt
            context.insert(friend)
            for w in f.wants {
                let want = TradeWant(theyWant: w.theyWant, speciesId: w.speciesId, speciesName: w.speciesName, note: w.note)
                want.isShiny = w.isShiny
                want.isDone = w.isDone
                want.createdAt = w.createdAt
                context.insert(want)
                want.friend = friend
            }
        }
        for (key, value) in backup.settings where settingsKeys.contains(key) {
            UserDefaults.standard.set(value, forKey: key)
        }
        try context.save()
    }

    // MARK: - Undo copy (inside the app)

    private static var undoURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("before-last-restore.json")
    }

    static var undoAvailable: Bool {
        undoURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    private static func saveUndoCopy(_ context: ModelContext) throws {
        guard let url = undoURL else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try snapshot(context).encoded().write(to: url, options: .atomic)
    }

    /// Puts back the data from before the last restore (and keeps today's data as the new undo copy).
    static func undoLastRestore(into context: ModelContext) throws {
        guard let url = undoURL else { return }
        let backup = try AppBackup.decode(try Data(contentsOf: url))
        try restore(backup, into: context)
    }

    // MARK: - Automatic backups to a chosen folder

    /// Remembers a folder picked in Files (for example in iCloud Drive).
    static func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: folderBookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: folderNameKey)
        UserDefaults.standard.removeObject(forKey: lastErrorKey)
    }

    static func clearFolder() {
        UserDefaults.standard.removeObject(forKey: folderBookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
        UserDefaults.standard.set(false, forKey: autoEnabledKey)
    }

    /// Writes a dated backup into the chosen folder and keeps only the newest `keepCount`.
    @discardableResult
    static func backUpToFolder(_ context: ModelContext) throws -> String {
        guard let bookmark = UserDefaults.standard.data(forKey: folderBookmarkKey) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        if stale, let fresh = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: folderBookmarkKey)
        }

        let data = try snapshot(context).encoded()
        let name = AppBackup.fileName(for: .now)
        let target = folder.appendingPathComponent(name)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinationError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }

        // Prune old automatic backups (only files with our own name pattern).
        if let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) {
            for old in AppBackup.filesToPrune(names, keep: keepCount) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
            }
        }
        let now = Date.now
        UserDefaults.standard.set(now, forKey: lastAutoKey)
        UserDefaults.standard.removeObject(forKey: lastErrorKey)
        markBackedUp(at: now)
        return name
    }

    /// Called when the app becomes active: backs up when automatic backups are on and the last
    /// one is more than a day old. Errors are remembered for the Backup screen, never shown as alerts.
    static func autoBackupIfDue(_ context: ModelContext) {
        guard autoEnabled, hasFolder else { return }
        if let last = UserDefaults.standard.object(forKey: lastAutoKey) as? Date, Date.now.timeIntervalSince(last) < autoInterval {
            return
        }
        do {
            try backUpToFolder(context)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: lastErrorKey)
        }
    }
}
