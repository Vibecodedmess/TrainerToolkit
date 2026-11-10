import Foundation
import SwiftData
import SearchBuilder

/// A search the user saved under a name. The filter selection is stored as JSON.
@Model
final class SavedSearchPreset {
    var name: String
    var stateData: Data
    var createdAt: Date

    init(name: String, state: SearchState, createdAt: Date = .now) {
        self.name = name
        self.stateData = (try? JSONEncoder().encode(state)) ?? Data()
        self.createdAt = createdAt
    }

    var state: SearchState {
        (try? JSONDecoder().decode(SearchState.self, from: stateData)) ?? SearchState()
    }
}
