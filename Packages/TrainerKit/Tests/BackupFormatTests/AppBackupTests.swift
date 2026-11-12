import XCTest
@testable import BackupFormat

/// Made-up data only.
final class AppBackupTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000) // whole seconds survive ISO 8601

    private func sample() -> AppBackup {
        AppBackup(
            createdAt: date, appVersion: "1.0 (1)",
            collection: [.init(speciesId: "examplemon", speciesName: "Examplemon", nickname: "Ex", baseAttack: 100,
                               baseDefense: 90, baseStamina: 80, ivAttack: 1, ivDefense: 2, ivStamina: 3, levelHalfSteps: 41,
                               fastMoveId: "FAST", chargedMoveId: "CHARGED", secondChargedMoveId: "", isShadow: true,
                               isPurified: false, isShiny: true, isLucky: false, notes: "note", source: "screenshot",
                               createdAt: date, updatedAt: date)],
            goals: [.init(speciesId: "examplemon", speciesName: "Examplemon", baseAttack: 100, baseDefense: 90, baseStamina: 80,
                          ivAttack: 1, ivDefense: 2, ivStamina: 3, currentLevelHalfSteps: 41, targetLevelHalfSteps: 80,
                          isShadow: true, isPurified: false, isLucky: false, isBestBuddy: false, candyOwned: 12,
                          xlCandyOwned: 3, candyIncome: 1.5, xlCandyIncome: 0.25, incomeIsPerWeek: true, createdAt: date)],
            eventPlans: [.init(eventID: "event-1", eventName: "An event", exclusiveMove: "Move", evolveDeadline: date,
                               remindBeforeStart: true, remindBeforeDeadline: false, reminderLeadMinutes: 30)],
            checklist: [.init(eventID: "event-1", text: "Do a thing", isDone: true, order: 0, createdAt: date)],
            searchPresets: [.init(name: "Preset", stateData: Data("{\"a\":1}".utf8), createdAt: date)],
            tradeFriends: [.init(name: "Friend", friendshipLevel: 3, isLuckyFriend: true, notes: "", nextLevelDate: nil,
                                 createdAt: date,
                                 wants: [.init(theyWant: true, speciesId: "examplemon", speciesName: "Examplemon", note: "",
                                               isShiny: false, isDone: false, createdAt: date)])],
            settings: ["trades.baseCost.regularRegistered": 100])
    }

    func testRoundTrip() throws {
        let backup = sample()
        let decoded = try AppBackup.decode(try backup.encoded())
        XCTAssertEqual(decoded, backup)
        XCTAssertEqual(decoded.format, AppBackup.formatName)
        XCTAssertEqual(decoded.version, AppBackup.currentVersion)
        XCTAssertFalse(decoded.isEmpty)
        XCTAssertEqual(decoded.summary.first { $0.label == "Want list entries" }?.count, 1)
    }

    func testRejectsOtherFilesAndNewerVersions() throws {
        XCTAssertThrowsError(try AppBackup.decode(Data("{\"hello\":1}".utf8))) {
            XCTAssertEqual($0 as? AppBackup.BackupError, .notABackup)
        }
        XCTAssertThrowsError(try AppBackup.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? AppBackup.BackupError, .notABackup)
        }
        var newer = sample()
        newer.version = AppBackup.currentVersion + 1
        XCTAssertThrowsError(try AppBackup.decode(try newer.encoded())) {
            XCTAssertEqual($0 as? AppBackup.BackupError, .newerVersion(AppBackup.currentVersion + 1))
        }
    }

    func testEmpty() {
        XCTAssertTrue(AppBackup(createdAt: date, appVersion: "x").isEmpty)
    }

    func testFileNamesAndPruning() {
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(AppBackup.fileName(for: date, timeZone: utc), "TrainerToolkit-backup-2027-01-15-0800.json")
        let names = ["TrainerToolkit-backup-2026-01-01-0900.json", "TrainerToolkit-backup-2026-03-01-0900.json",
                     "TrainerToolkit-backup-2026-02-01-0900.json", "notes.txt", "TrainerToolkit-before-restore-2026-01-01-0900.json"]
        XCTAssertEqual(AppBackup.filesToPrune(names, keep: 2), ["TrainerToolkit-backup-2026-01-01-0900.json"])
        XCTAssertEqual(AppBackup.filesToPrune(names, keep: 5), [])
    }
}
