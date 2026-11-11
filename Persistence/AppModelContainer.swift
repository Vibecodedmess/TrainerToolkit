import Foundation
import SwiftData

/// The on-device SwiftData store for everything the user creates.
/// Add new @Model types to `schema` as later phases introduce them.
enum AppModelContainer {
    static let schema = Schema([SavedSearchPreset.self, PowerUpGoal.self, EventPlan.self, ChecklistItem.self,
                                CollectedPokemon.self, TradeFriend.self, TradeWant.self])

    /// Opens the store on disk. If that fails, falls back to an in-memory store so the app
    /// still opens (nothing would be saved in that case, and `usingFallback` says so).
    static func make() -> (container: ModelContainer, usingFallback: Bool) {
        do {
            return (try ModelContainer(for: schema), false)
        } catch {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // An in-memory store with a valid schema cannot realistically fail.
            return (try! ModelContainer(for: schema, configurations: memory), true)
        }
    }
}
