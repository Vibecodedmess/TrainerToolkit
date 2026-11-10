import Foundation
import SwiftData

/// One Pokémon in My Collection, entered by hand (or, later, imported from a CSV export).
/// Base stats are copied in so CP still shows if the Pokémon later disappears from the data.
@Model
final class CollectedPokemon {
    var speciesId: String
    /// PvPoke display name; includes the form, e.g. "Meowth (Galarian)".
    var speciesName: String
    var nickname: String
    var baseAttack: Int
    var baseDefense: Int
    var baseStamina: Int
    var ivAttack: Int
    var ivDefense: Int
    var ivStamina: Int
    /// Level x 2 (20.5 is stored as 41).
    var levelHalfSteps: Int
    var fastMoveId: String
    var chargedMoveId: String
    /// Second charged move, empty if not unlocked.
    var secondChargedMoveId: String
    var isShadow: Bool
    var isPurified: Bool
    var isShiny: Bool
    var isLucky: Bool
    var notes: String
    /// "manual", or the import source.
    var source: String
    var createdAt: Date
    var updatedAt: Date

    init(speciesId: String, speciesName: String, baseAttack: Int, baseDefense: Int, baseStamina: Int,
         levelHalfSteps: Int, source: String = "manual") {
        self.speciesId = speciesId
        self.speciesName = speciesName
        nickname = ""
        self.baseAttack = baseAttack
        self.baseDefense = baseDefense
        self.baseStamina = baseStamina
        ivAttack = 0
        ivDefense = 0
        ivStamina = 0
        self.levelHalfSteps = levelHalfSteps
        fastMoveId = ""
        chargedMoveId = ""
        secondChargedMoveId = ""
        isShadow = false
        isPurified = false
        isShiny = false
        isLucky = false
        notes = ""
        self.source = source
        createdAt = .now
        updatedAt = .now
    }
}
