import SwiftUI
import GameMath

/// Shared access to the bundled friendship / trade tables (PokeMiners game master).
enum TradeData {
    static let tables: TradeTables? = try? TradeTables.bundled()
}

/// The four kinds of trade the user enters a base stardust cost for.
/// "Registered" = already in the Pokédex. The base costs themselves are not in any data source.
enum TradeKind: String, CaseIterable, Identifiable {
    case regularRegistered
    case regularNotRegistered
    case specialRegistered
    case specialNotRegistered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regularRegistered: return "Regular, registered"
        case .regularNotRegistered: return "Regular, not registered"
        case .specialRegistered: return "Special, registered"
        case .specialNotRegistered: return "Special, not registered"
        }
    }

    /// The game master `unlockedTrading` id that matches this kind, when there is exactly one.
    /// "Special, not registered" has no single id (the data splits it into regional, form,
    /// legendary, shiny, ... ids), so the unlock list is shown instead.
    /// TODO: verify: this mapping is read from the id names, the game master doesn't define it.
    var unlockCategoryId: String? {
        switch self {
        case .regularRegistered: return "REGULAR_IN_POKEDEX"
        case .regularNotRegistered: return "REGULAR_NON_POKEDEX"
        case .specialRegistered: return "SPECIAL_IN_POKEDEX"
        case .specialNotRegistered: return nil
        }
    }
}

/// The user's base trade costs (stardust before any friendship discount), stored in UserDefaults.
/// 0 = not entered. Use as a view property so views refresh when a value changes.
struct BaseTradeCosts: DynamicProperty {
    @AppStorage("trades.baseCost.regularRegistered") private var regularRegistered = 0
    @AppStorage("trades.baseCost.regularNotRegistered") private var regularNotRegistered = 0
    @AppStorage("trades.baseCost.specialRegistered") private var specialRegistered = 0
    @AppStorage("trades.baseCost.specialNotRegistered") private var specialNotRegistered = 0

    init() {}

    /// The entered base cost, or nil when none was entered.
    func base(for kind: TradeKind) -> Int? {
        let value = binding(for: kind).wrappedValue
        return value > 0 ? value : nil
    }

    func binding(for kind: TradeKind) -> Binding<Int> {
        switch kind {
        case .regularRegistered: return $regularRegistered
        case .regularNotRegistered: return $regularNotRegistered
        case .specialRegistered: return $specialRegistered
        case .specialNotRegistered: return $specialNotRegistered
        }
    }

    var isEmpty: Bool { TradeKind.allCases.allSatisfy { base(for: $0) == nil } }

    func clear() {
        for kind in TradeKind.allCases {
            let value = binding(for: kind)
            value.wrappedValue = 0
        }
    }
}

/// Text for friendship levels and trade numbers. Level names are not in the data, so levels are numbered.
enum TradeFormat {
    static func levelTitle(_ number: Int) -> String { "Level \(number)" }

    /// "from 7 points", "from 90 points, +90 relative points"; nil when the data gives no points.
    static func pointsText(_ level: TradeTables.FriendshipLevel) -> String? {
        var parts: [String] = []
        if let points = level.minPointsToReach { parts.append("from \(points) points") }
        if let relative = level.relativePointsToReach { parts.append("+\(relative) relative points") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Label for a level picker row: "Level 2 · 7 pts".
    static func pickerLabel(_ level: TradeTables.FriendshipLevel) -> String {
        var text = levelTitle(level.level)
        if let points = level.minPointsToReach { text += " · \(points) pts" }
        if let relative = level.relativePointsToReach { text += " (+\(relative) relative)" }
        return text
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...1)))
    }

    /// The game master's attackBonusPercentage values are multipliers (1.0 = no bonus).
    /// TODO: verify that the game applies it as a plain multiplier.
    static func multiplier(_ value: Double) -> String {
        "×" + value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func stardust(_ value: Int) -> String { "\(value.formatted()) stardust" }

    /// Levels the data gives no trading discount, e.g. "0, 1" (for the base cost hint).
    static func levelsWithoutDiscount(_ tables: TradeTables) -> String {
        tables.friendshipLevels.filter { ($0.tradingDiscount ?? 0) <= 0 }.map { String($0.level) }.joined(separator: ", ")
    }
}
