import Foundation

/// Evolution requirements from PokeMiners' game master, with the game's own English names for
/// items and quest text (PokeMiners pogo_assets). Extracted by scripts/update-evolution-tables.ps1.
/// Mega evolutions are not included. How to *get* an item is not in this data: see `EvolutionItemGuide`.
public struct EvolutionTables: Decodable, Sendable {
    /// One way a Pokémon can evolve. Ids are the game master's ("SCYTHER", form "SANDSHREW_ALOLA").
    public struct Branch: Decodable, Sendable, Hashable {
        public let pokemonId: String
        /// nil = the plain form.
        public let form: String?
        public let evolution: String
        public let evolutionForm: String?
        public let candyCost: Int?
        public let candyCostPurified: Int?
        /// Evolution item id, e.g. "ITEM_METAL_COAT".
        public let item: String?
        /// How many of the item (only when more than one is needed).
        public let itemCost: Int?
        /// Lure Module the PokéStop must have, e.g. "ITEM_TROY_DISK_MOSSY".
        public let lure: String?
        public let kmBuddyDistance: Double?
        public let mustBeBuddy: Bool
        public let onlyDaytime: Bool
        public let onlyNighttime: Bool
        public let onlyDusk: Bool
        public let onlyFullMoon: Bool
        public let onlyUpsideDown: Bool
        /// "MALE" or "FEMALE".
        public let gender: String?
        public let noCandyCostViaTrade: Bool
        /// Evolution quest id; its text is in `quest(_:)`.
        public let quest: String?

        /// The evolved Pokémon in PvPoke's id style ("scizor", "sandslash_alolan").
        public var targetKey: String { EvolutionTables.speciesKey(pokemonId: evolution, form: evolutionForm) }

        /// Anything beyond candy: an item, a lure, a quest, buddy, time, gender or trade rule.
        public var needsMoreThanCandy: Bool {
            item != nil || lure != nil || quest != nil || kmBuddyDistance != nil || mustBeBuddy || onlyDaytime
                || onlyNighttime || onlyDusk || onlyFullMoon || onlyUpsideDown || gender != nil
        }

        /// Everything except the source form, for merging cosmetic forms that evolve the same way.
        fileprivate var signature: [String] {
            [evolution, evolutionForm ?? "", "\(candyCost ?? -1)", "\(candyCostPurified ?? -1)", item ?? "", "\(itemCost ?? -1)",
             lure ?? "", "\(kmBuddyDistance ?? -1)", "\(mustBeBuddy)", "\(onlyDaytime)", "\(onlyNighttime)", "\(onlyDusk)",
             "\(onlyFullMoon)", "\(onlyUpsideDown)", gender ?? "", "\(noCandyCostViaTrade)", quest ?? ""]
        }
    }

    public struct Item: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        /// The game's English name, e.g. "Metal Coat".
        public let name: String
        /// The game's English description.
        public let description: String?
    }

    public struct Quest: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        /// The game's text with the goal filled in, e.g. "Walk 10 km with your buddy".
        public let text: String?
    }

    public let source: LevelTables.Source
    public let branches: [Branch]
    public let items: [Item]
    public let quests: [Quest]

    private let bySpecies: [String: [Branch]]
    private let itemsById: [String: Item]
    private let questsById: [String: Quest]

    enum CodingKeys: String, CodingKey { case source, branches, items, quests }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(LevelTables.Source.self, forKey: .source)
        branches = try c.decode([Branch].self, forKey: .branches)
        items = try c.decode([Item].self, forKey: .items)
        quests = try c.decode([Quest].self, forKey: .quests)
        itemsById = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        questsById = Dictionary(quests.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Regional forms are separate species in PvPoke ("sandshrew_alolan"); other forms (cosmetic
        // ones such as patterns) are filed under the plain species too, merged when they evolve alike.
        var index: [String: [Branch]] = [:]
        var seen: [String: Set<[String]>] = [:]
        func add(_ b: Branch, under key: String) {
            guard seen[key, default: []].insert(b.signature).inserted else { return }
            index[key, default: []].append(b)
        }
        for b in branches {
            let key = Self.speciesKey(pokemonId: b.pokemonId, form: b.form)
            add(b, under: key)
            let base = b.pokemonId.lowercased()
            if key != base && !Self.isRegional(key) { add(b, under: base) }
        }
        bySpecies = index
    }

    public static func bundled() throws -> EvolutionTables {
        guard let url = Bundle.module.url(forResource: "evolution-tables", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(EvolutionTables.self, from: Data(contentsOf: url))
    }

    /// Ways a species (PvPoke id, e.g. "scyther" or "sandshrew_alolan") can evolve. A "_shadow"
    /// suffix is ignored: shadow Pokémon evolve like the regular one.
    public func branches(forSpecies speciesId: String) -> [Branch] {
        var id = speciesId.lowercased()
        if id.hasSuffix("_shadow") { id = String(id.dropLast("_shadow".count)) }
        return bySpecies[id] ?? []
    }

    public func item(_ id: String) -> Item? { itemsById[id] }
    public func quest(_ id: String) -> Quest? { questsById[id] }

    // MARK: - Ids

    static let regionalSuffixes: [String: String] = ["alola": "alolan", "alolan": "alolan", "galarian": "galarian",
                                                     "galar": "galarian", "hisuian": "hisuian", "paldea": "paldean",
                                                     "paldean": "paldean"]

    /// Game master id + form -> PvPoke-style species id: ("SANDSHREW", "SANDSHREW_ALOLA") -> "sandshrew_alolan".
    public static func speciesKey(pokemonId: String, form: String?) -> String {
        let base = pokemonId.lowercased()
        guard let form, !form.isEmpty else { return base }
        var suffix = form.uppercased().hasPrefix(pokemonId.uppercased() + "_")
            ? String(form.dropFirst(pokemonId.count + 1)) : form
        suffix = suffix.lowercased()
        if suffix == "normal" { return base }
        return base + "_" + (regionalSuffixes[suffix] ?? suffix)
    }

    static func isRegional(_ key: String) -> Bool {
        Set(regionalSuffixes.values).contains { key.hasSuffix("_" + $0) }
    }
}

/// How to get each evolution item, from a community wiki (paraphrased, cited, marked unverified in
/// the app). Hand-written in Resources/evolution-items-community.json; not game data.
public struct EvolutionItemGuide: Decodable, Sendable {
    public struct Source: Decodable, Sendable, Hashable {
        public let name: String
        public let pages: [String]
        public let retrieved: String
        public let license: String
        public let note: String
    }

    public let source: Source
    /// Item id -> how to get it.
    public let items: [String: String]

    public static func bundled() throws -> EvolutionItemGuide {
        guard let url = Bundle.module.url(forResource: "evolution-items-community", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(EvolutionItemGuide.self, from: Data(contentsOf: url))
    }

    public func howToGet(_ itemId: String) -> String? { items[itemId] }
}
