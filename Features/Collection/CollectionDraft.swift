import Foundation
import GameMath
import DataSources

/// Editable copy of a collection entry. Saved into `CollectedPokemon`.
struct CollectionDraft: Equatable {
    var speciesId: String?
    var speciesName = ""
    var types: [String] = []
    var base: BaseStats?
    var nickname = ""
    var ivs = IVs(attack: 10, defense: 10, stamina: 10)
    var level = PokemonLevel(20)
    var fastMoveId = ""
    var chargedMoveId = ""
    var secondChargedMoveId = ""
    var isShadow = false
    var isPurified = false
    var isShiny = false
    var isLucky = false
    var notes = ""

    var isComplete: Bool { speciesId != nil && base != nil }

    func cp(_ tables: LevelTables) -> Int? {
        guard let base else { return nil }
        return CPCalculator.cp(base: base, ivs: ivs, level: level, tables: tables)
    }

    func hp(_ tables: LevelTables) -> Int? {
        guard let base else { return nil }
        return CPCalculator.hp(base: base, ivs: ivs, level: level, tables: tables)
    }

    /// Picks a Pokémon. Moves it can't know are cleared.
    mutating func select(_ pokemon: GMPokemon, lookup: GamemasterLookup?) {
        speciesId = pokemon.speciesId
        speciesName = pokemon.speciesName
        types = pokemon.realTypes
        base = pokemon.stats
        if pokemon.tags.contains("shadow") { isShadow = true; isPurified = false; isLucky = false }
        if let lookup {
            let options = lookup.moveOptions(for: pokemon)
            let fast = Set(options.fast.map(\.id)), charged = Set(options.charged.map(\.id))
            if !fast.contains(fastMoveId) { fastMoveId = "" }
            if !charged.contains(chargedMoveId) { chargedMoveId = "" }
            if !charged.contains(secondChargedMoveId) { secondChargedMoveId = "" }
        }
    }
}

extension CollectionDraft {
    init(pokemon p: CollectedPokemon, types: [String]) {
        speciesId = p.speciesId
        speciesName = p.speciesName
        self.types = types
        base = BaseStats(attack: p.baseAttack, defense: p.baseDefense, stamina: p.baseStamina)
        nickname = p.nickname
        ivs = IVs(attack: p.ivAttack, defense: p.ivDefense, stamina: p.ivStamina)
        level = PokemonLevel(halfSteps: p.levelHalfSteps)
        fastMoveId = p.fastMoveId
        chargedMoveId = p.chargedMoveId
        secondChargedMoveId = p.secondChargedMoveId
        isShadow = p.isShadow
        isPurified = p.isPurified
        isShiny = p.isShiny
        isLucky = p.isLucky
        notes = p.notes
    }

    /// Copies into an existing entry, or creates a new one. Nil if no Pokémon is picked.
    func apply(to existing: CollectedPokemon?) -> CollectedPokemon? {
        guard let speciesId, let base else { return nil }
        let p = existing ?? CollectedPokemon(speciesId: speciesId, speciesName: speciesName,
                                             baseAttack: base.attack, baseDefense: base.defense,
                                             baseStamina: base.stamina, levelHalfSteps: level.halfSteps)
        p.speciesId = speciesId
        p.speciesName = speciesName
        p.baseAttack = base.attack
        p.baseDefense = base.defense
        p.baseStamina = base.stamina
        p.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        p.ivAttack = ivs.attack
        p.ivDefense = ivs.defense
        p.ivStamina = ivs.stamina
        p.levelHalfSteps = level.halfSteps
        p.fastMoveId = fastMoveId
        p.chargedMoveId = chargedMoveId
        p.secondChargedMoveId = secondChargedMoveId
        p.isShadow = isShadow
        p.isPurified = isPurified
        p.isShiny = isShiny
        p.isLucky = isLucky
        p.notes = notes
        p.updatedAt = .now
        return p
    }
}

extension CollectedPokemon {
    var level: PokemonLevel { PokemonLevel(halfSteps: levelHalfSteps) }
    var ivs: IVs { IVs(attack: ivAttack, defense: ivDefense, stamina: ivStamina) }
    var baseStats: BaseStats { BaseStats(attack: baseAttack, defense: baseDefense, stamina: baseStamina) }

    func cp(_ tables: LevelTables) -> Int? {
        CPCalculator.cp(base: baseStats, ivs: ivs, level: level, tables: tables)
    }

    var displayName: String { nickname.isEmpty ? speciesName : "\(nickname) (\(speciesName))" }

    var chargedMoveIds: [String] { [chargedMoveId, secondChargedMoveId].filter { !$0.isEmpty } }

    /// Same species, IVs, level and shadow status = treated as the same Pokémon (import duplicate checks).
    static func makeDuplicateKey(speciesId: String, ivs: IVs, level: PokemonLevel, isShadow: Bool) -> String {
        "\(speciesId)|\(ivs.attack)|\(ivs.defense)|\(ivs.stamina)|\(level.halfSteps)|\(isShadow)"
    }

    var duplicateKey: String {
        CollectedPokemon.makeDuplicateKey(speciesId: speciesId, ivs: ivs, level: level, isShadow: isShadow)
    }
}
