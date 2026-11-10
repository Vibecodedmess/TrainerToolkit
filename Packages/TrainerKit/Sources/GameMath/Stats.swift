import Foundation

/// A Pokémon level in half-level steps (1, 1.5, 2, ... 51). Stored as an integer to avoid
/// floating-point surprises: `halfSteps` = level x 2.
public struct PokemonLevel: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let halfSteps: Int

    public init(halfSteps: Int) {
        self.halfSteps = halfSteps
    }

    public init(_ level: Double) {
        halfSteps = Int((level * 2).rounded())
    }

    public var value: Double { Double(halfSteps) / 2 }
    public var isWhole: Bool { halfSteps % 2 == 0 }
    public var wholeLevel: Int { halfSteps / 2 }
    public var next: PokemonLevel { PokemonLevel(halfSteps: halfSteps + 1) }

    public var description: String {
        isWhole ? "\(wholeLevel)" : "\(wholeLevel).5"
    }

    public static func < (lhs: PokemonLevel, rhs: PokemonLevel) -> Bool {
        lhs.halfSteps < rhs.halfSteps
    }

    /// Every half level from `start` through `end`.
    public static func all(from start: PokemonLevel, through end: PokemonLevel) -> [PokemonLevel] {
        guard start <= end else { return [] }
        return (start.halfSteps...end.halfSteps).map { PokemonLevel(halfSteps: $0) }
    }
}

public struct BaseStats: Hashable, Codable, Sendable {
    public let attack: Int
    public let defense: Int
    public let stamina: Int

    public init(attack: Int, defense: Int, stamina: Int) {
        self.attack = attack
        self.defense = defense
        self.stamina = stamina
    }
}

public struct IVs: Hashable, Codable, Sendable {
    public static let range = 0...15

    public var attack: Int
    public var defense: Int
    public var stamina: Int

    public init(attack: Int, defense: Int, stamina: Int) {
        self.attack = attack
        self.defense = defense
        self.stamina = stamina
    }

    public static let perfect = IVs(attack: 15, defense: 15, stamina: 15)
    public static let zero = IVs(attack: 0, defense: 0, stamina: 0)

    public var percent: Int {
        Int((Double(attack + defense + stamina) / 45 * 100).rounded())
    }
}
