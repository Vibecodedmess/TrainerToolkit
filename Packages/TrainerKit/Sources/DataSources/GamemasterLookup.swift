import Foundation

/// Name and evolution lookups on PvPoke's gamemaster, for matching ScrapedDuck's display
/// names ("Galarian Meowth", "Pawniard") to gamemaster entries ("meowth_galarian").
public struct GamemasterLookup: Sendable {
    private let byId: [String: GMPokemon]
    private let byKey: [String: GMPokemon]
    private let moveNames: [String: String]

    public init(_ gamemaster: Gamemaster) {
        var byId: [String: GMPokemon] = [:]
        var byKey: [String: GMPokemon] = [:]
        // Base (non-shadow, non-mega) entries win when two entries share a display name.
        let ordered = gamemaster.pokemon.sorted { Self.priority($0) < Self.priority($1) }
        for p in ordered {
            byId[p.speciesId] = byId[p.speciesId] ?? p
            for key in Self.keys(for: p.speciesName) where byKey[key] == nil {
                byKey[key] = p
            }
        }
        self.byId = byId
        self.byKey = byKey
        moveNames = Dictionary(gamemaster.moves.map { ($0.moveId, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    public func pokemon(id: String) -> GMPokemon? { byId[id] }

    /// Finds a Pokémon by a display name such as "Pawniard", "Galarian Meowth" or "Meowth (Galarian)".
    public func pokemon(named name: String) -> GMPokemon? {
        for key in Self.keys(for: name) {
            if let p = byKey[key] { return p }
        }
        return nil
    }

    /// The Pokémon itself followed by everything it can evolve into (breadth-first, no duplicates).
    public func evolutionLine(from start: GMPokemon) -> [GMPokemon] {
        var result: [GMPokemon] = [start]
        var queue = [start]
        var seen: Set<String> = [start.speciesId]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for id in current.family?.evolutions ?? [] where !seen.contains(id) {
                seen.insert(id)
                if let next = byId[id] {
                    result.append(next)
                    queue.append(next)
                }
            }
        }
        return result
    }

    /// Readable move name for a move id ("SHADOW_BALL" -> "Shadow Ball").
    public func moveName(_ id: String) -> String {
        moveNames[id] ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // MARK: - Name matching

    static let regionalPrefixes = ["Alolan", "Galarian", "Hisuian", "Paldean"]

    /// Normalised lookup keys: "Meowth (Galarian)" and "Galarian Meowth" both give "galarian meowth".
    static func keys(for name: String) -> [String] {
        var keys = [normalize(name)]
        // "Meowth (Galarian)" -> "Galarian Meowth"
        if let open = name.firstIndex(of: "("), let close = name.lastIndex(of: ")"), open < close {
            let base = name[..<open].trimmingCharacters(in: .whitespaces)
            let form = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            keys.append(normalize("\(form) \(base)"))
        }
        return keys
    }

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .split(separator: " ").joined(separator: " ")
    }

    private static func priority(_ p: GMPokemon) -> Int {
        if p.tags.contains("shadow") || p.speciesId.hasSuffix("_shadow") { return 2 }
        if p.tags.contains("mega") || p.speciesId.contains("_mega") { return 1 }
        return 0
    }
}
