import Foundation
import SwiftData

/// The on-device SwiftData store for everything the user creates.
/// Add every new @Model type to `schema`, and to the backup (see `BackupManager`).
enum AppModelContainer {
    static let schema = Schema([SavedSearchPreset.self, PowerUpGoal.self, EventPlan.self, ChecklistItem.self,
                                CollectedPokemon.self, TradeFriend.self, TradeWant.self])

    /// The app's store, opened once.
    static let shared = make()

    /// Shown on Home when the store on disk couldn't be opened, else nil.
    static var fallbackWarning: String? {
        shared.usingFallback ? "Your data couldn't be opened, so nothing you change now is saved. Automatic backups are paused." : nil
    }

    /// Opens the store on disk. If that fails, falls back to an in-memory store so the app
    /// still opens (nothing would be saved in that case, and `usingFallback` says so).
    private static func make() -> (container: ModelContainer, usingFallback: Bool) {
        do {
            return (try ModelContainer(for: schema), false)
        } catch {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // An in-memory store with a valid schema cannot realistically fail.
            return (try! ModelContainer(for: schema, configurations: memory), true)
        }
    }
}
