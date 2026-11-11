import Foundation
import SwiftData

/// A friend in the Trade Planner. Everything here is typed in by the user.
@Model
final class TradeFriend {
    var name: String
    /// Friendship level number as in the game master (FRIENDSHIP_LEVEL_<n>), 0 = just added.
    var friendshipLevel: Int
    var isLuckyFriend: Bool
    var notes: String
    /// When the next friendship level is (or was) reached, if the user knows it.
    var nextLevelDate: Date?
    var createdAt: Date
    /// Both want lists ("they want" and "I want"); deleted together with the friend.
    @Relationship(deleteRule: .cascade, inverse: \TradeWant.friend)
    var wants: [TradeWant] = []

    init(name: String, friendshipLevel: Int = 0) {
        self.name = name
        self.friendshipLevel = friendshipLevel
        isLuckyFriend = false
        notes = ""
        nextLevelDate = nil
        createdAt = .now
    }
}

/// One entry on a friend's want list: a species from the gamemaster and/or a free-text note.
@Model
final class TradeWant {
    /// true = on the friend's "they want" list, false = on my "I want" list.
    var theyWant: Bool
    /// PvPoke species id, empty when the entry is only a note.
    var speciesId: String
    /// PvPoke display name, copied in so it still shows if the species leaves the data.
    var speciesName: String
    var note: String
    var isShiny: Bool
    var isDone: Bool
    var createdAt: Date
    var friend: TradeFriend?

    init(theyWant: Bool, speciesId: String = "", speciesName: String = "", note: String = "") {
        self.theyWant = theyWant
        self.speciesId = speciesId
        self.speciesName = speciesName
        self.note = note
        isShiny = false
        isDone = false
        createdAt = .now
        friend = nil
    }

    /// Species name, or the note when no species is set.
    var title: String {
        if !speciesName.isEmpty { return speciesName }
        return note.isEmpty ? "Untitled" : note
    }
}
