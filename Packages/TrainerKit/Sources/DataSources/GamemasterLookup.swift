import Foundation

/// Name and evolution lookups on PvPoke's gamemaster, for matching ScrapedDuck's display
/// names ("Galarian Meowth", "Pawniard") to gamemaster entries ("meowth_galarian").
public struct GamemasterLookup: Sendable {
    private let byId: [String: GMPokemon]
    private let byKey: [String: GMPokemon]
    private let moveNames: [String: String]
    private let movesById: [String: GMMove]

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
        movesById = Dictionary(gamemaster.moves.map { ($0.moveId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public func move(_ id: String) -> GMMove? { movesById[id] }

    /// Move id from a display name ("Mud Shot", "mud shot") or an id ("MUD_SHOT"). Nil if unknown.
    public func moveId(named text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if movesById[trimmed.uppercased()] != nil { return trimmed.uppercased() }
        let key = Self.normalize(trimmed.replacingOccurrences(of: "_", with: " "))
        return movesById.values.first { Self.normalize($0.name) == key }?.moveId
    }

    /// For a shadow entry ("bulbasaur_shadow") returns the regular entry; otherwise the Pokémon itself.
    public func regularForm(of pokemon: GMPokemon) -> GMPokemon {
        guard pokemon.speciesId.hasSuffix("_shadow"),
              let regular = byId[String(pokemon.speciesId.dropLast("_shadow".count))] else { return pokemon }
        return regular
    }

    public struct MoveOption: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let type: String
        /// Elite (Elite TM / event-only) or legacy move per PvPoke.
        public let isSpecial: Bool
    }

    /// Fast and charged moves a Pokémon can know, per PvPoke (including elite and legacy moves,
    /// which are flagged). Sorted by name. Unknown move ids are skipped.
    public func moveOptions(for pokemon: GMPokemon) -> (fast: [MoveOption], charged: [MoveOption]) {
        let special = Set(pokemon.eliteMoves + pokemon.legacyMoves)
        var seen: Set<String> = []
        var fast: [MoveOption] = []
        var charged: [MoveOption] = []
        for id in pokemon.fastMoves + pokemon.chargedMoves + pokemon.eliteMoves + pokemon.legacyMoves {
            guard !seen.contains(id), let move = movesById[id] else { continue }
            seen.insert(id)
            let option = MoveOption(id: id, name: move.name, type: move.type, isSpecial: special.contains(id))
            if move.isFastMove { fast.append(option) } else { charged.append(option) }
        }
        return (fast.sorted { $0.name < $1.name }, charged.sorted { $0.name < $1.name })
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
