import Foundation
import SwiftData

/// A saved power-up goal in the Candy & Stardust Planner.
/// Base stats are copied in when the goal is saved, so a goal keeps working even if the
/// Pokémon later disappears from (or changes in) the downloaded data.
@Model
final class PowerUpGoal {
    var speciesId: String
    var speciesName: String
    var baseAttack: Int
    var baseDefense: Int
    var baseStamina: Int
    var ivAttack: Int
    var ivDefense: Int
    var ivStamina: Int
    /// Level x 2 (so 20.5 is stored as 41).
    var currentLevelHalfSteps: Int
    var targetLevelHalfSteps: Int
    var isShadow: Bool
    var isPurified: Bool
    var isLucky: Bool
    var isBestBuddy: Bool
    var candyOwned: Int
    var xlCandyOwned: Int
    /// Income as entered by the trainer, per day or per week (see `incomeIsPerWeek`).
    var candyIncome: Double
    var xlCandyIncome: Double
    var incomeIsPerWeek: Bool
    var createdAt: Date

    init(speciesId: String, speciesName: String, baseAttack: Int, baseDefense: Int, baseStamina: Int,
         ivAttack: Int, ivDefense: Int, ivStamina: Int, currentLevelHalfSteps: Int, targetLevelHalfSteps: Int,
         isShadow: Bool, isPurified: Bool, isLucky: Bool, isBestBuddy: Bool,
         candyOwned: Int, xlCandyOwned: Int, candyIncome: Double, xlCandyIncome: Double,
         incomeIsPerWeek: Bool, createdAt: Date = .now) {
        self.speciesId = speciesId
        self.speciesName = speciesName
        self.baseAttack = baseAttack
        self.baseDefense = baseDefense
        self.baseStamina = baseStamina
        self.ivAttack = ivAttack
        self.ivDefense = ivDefense
        self.ivStamina = ivStamina
        self.currentLevelHalfSteps = currentLevelHalfSteps
        self.targetLevelHalfSteps = targetLevelHalfSteps
        self.isShadow = isShadow
        self.isPurified = isPurified
        self.isLucky = isLucky
        self.isBestBuddy = isBestBuddy
        self.candyOwned = candyOwned
        self.xlCandyOwned = xlCandyOwned
        self.candyIncome = candyIncome
        self.xlCandyIncome = xlCandyIncome
        self.incomeIsPerWeek = incomeIsPerWeek
        self.createdAt = createdAt
    }
}
