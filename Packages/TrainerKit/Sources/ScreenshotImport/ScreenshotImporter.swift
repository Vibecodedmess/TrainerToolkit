import Foundation
import DataSources
import GameMath

/// Turns readings of one Pokémon's screenshots into a proposal: species, level/IV options, moves, flags.
public enum ScreenshotImporter {
    /// How a "L30 80% 12/12/12" nickname was used for a species.
    public enum NicknameUse: Hashable, Sendable {
        /// No such nickname was read.
        case none
        /// It fits the CP, HP and stardust read from the screen: it is the answer.
        case matched
        /// The CP couldn't be read (or didn't fit any level/IVs), but the nickname fits the HP and
        /// stardust, so it is the answer.
        case usedWithoutCP
        /// It doesn't fit what was read, so it was ignored.
        case ignored
    }

    public struct SpeciesOption: Hashable, Sendable, Identifiable {
        public let pokemon: GMPokemon
        public let solutions: [IVSolver.Solution]
        public var nicknameUse: NicknameUse = .none
        public var id: String { pokemon.speciesId }
    }

    public struct Proposal: Hashable, Sendable {
        public let reading: ScreenReading
        /// IVs read from the appraisal bars (nil = no bar found).
        public let barIVs: IVSolver.Hints
        /// Species that fit the name/candy/types, best first. Each has its own level/IV solutions.
        public let options: [SpeciesOption]
        public let isShadow: Bool
        public let isLucky: Bool
        /// True when the stardust cost had to be ignored to find any solution.
        public let ignoredStardust: Bool

        /// Fast and charged move ids read from the screen for a species (only moves it can learn).
        public func moves(for pokemon: GMPokemon, lookup: GamemasterLookup) -> (fast: String?, charged: [String]) {
            let options = lookup.moveOptions(for: pokemon)
            let fastIds = Set(options.fast.map(\.id)), chargedIds = Set(options.charged.map(\.id))
            var fast: String?
            var charged: [String] = []
            for line in reading.moveLines {
                guard let id = lookup.moveId(named: line) else { continue }
                if fast == nil, fastIds.contains(id) { fast = id }
                else if chargedIds.contains(id), !charged.contains(id), charged.count < 2 { charged.append(id) }
            }
            return (fast, charged)
        }
    }

    public static func propose(_ reading: ScreenReading, barFractions: [AppraisalStat: Double],
                               gamemaster: Gamemaster, lookup: GamemasterLookup, tables: LevelTables) -> Proposal? {
        // Without a CP, a "L30 80% 12/12/12" nickname (checked against HP and stardust) can still decide.
        guard reading.cp != nil || reading.nickname != nil else { return nil }
        let hints = IVSolver.Hints(attack: barFractions[.attack].map(AppraisalBars.iv(fromFraction:)),
                                   defense: barFractions[.defense].map(AppraisalBars.iv(fromFraction:)),
                                   stamina: barFractions[.hp].map(AppraisalBars.iv(fromFraction:)))
        let species = candidates(reading, gamemaster: gamemaster, lookup: lookup)

        // Try the flags read from the screen first. A lucky Pokémon's power-up costs less, and LUCKY
        // isn't always readable, so retry as lucky; as a last resort ignore the stardust cost.
        let shadow = reading.isShadow
        let attempts: [(CostModifiers, Bool)] = [
            (CostModifiers(isShadow: shadow, isLucky: reading.isLucky), false),
            (CostModifiers(isShadow: shadow, isLucky: !reading.isLucky), false),
            (CostModifiers(isShadow: shadow, isLucky: reading.isLucky), true),
        ]
        for (modifiers, ignoreDust) in attempts {
            let options: [SpeciesOption] = species.compactMap { p in
                let base = BaseStats(attack: p.baseStats.atk, defense: p.baseStats.def, stamina: p.baseStats.hp)
                let (solutions, use) = solve(reading, base: base, barHints: hints, modifiers: modifiers,
                                             powerUpStardust: ignoreDust ? nil : reading.powerUpStardust, tables: tables)
                return solutions.isEmpty ? nil : SpeciesOption(pokemon: p, solutions: solutions, nicknameUse: use)
            }
            if !options.isEmpty || species.isEmpty {
                return Proposal(reading: reading, barIVs: hints, options: options, isShadow: shadow,
                                isLucky: modifiers.isLucky, ignoredStardust: ignoreDust && reading.powerUpStardust != nil)
            }
        }
        return Proposal(reading: reading, barIVs: hints, options: [], isShadow: shadow, isLucky: reading.isLucky, ignoredStardust: false)
    }

    /// Level/IV solutions for one species, using a "L30 80% 12/12/12" nickname when it fits.
    ///
    /// The nickname is checked first. Its level and IVs must give the HP read and the next power-up's
    /// stardust (each when read):
    /// - it also gives the CP read: the answer (`.matched`);
    /// - no CP was read, or the CP read differs (a digit hidden behind the Pokémon or misread), but the
    ///   HP was read and fits: the answer (`.usedWithoutCP`);
    /// - otherwise it's ignored (`.ignored`) and the usual solving from CP, HP, stardust and appraisal
    ///   bars runs. Without a CP that gives nothing: no answer is invented.
    static func solve(_ reading: ScreenReading, base: BaseStats, barHints: IVSolver.Hints, modifiers: CostModifiers,
                      powerUpStardust: Int?, tables: LevelTables) -> ([IVSolver.Solution], NicknameUse) {
        let nick = reading.nickname
        if let nick, nick.level <= tables.maxBestBuddyLevel {
            let hpOK = reading.hp.map { CPCalculator.hp(base: base, ivs: nick.ivs, level: nick.level, tables: tables) == $0 } ?? true
            let dustOK = powerUpStardust.map { dust in
                nick.level < tables.maxUpgradeLevel
                    && PowerUpCalculator.cost(from: nick.level, to: nick.level.next, modifiers: modifiers, tables: tables).stardust == dust
            } ?? true
            let cpOK = reading.cp.map { CPCalculator.cp(base: base, ivs: nick.ivs, level: nick.level, tables: tables) == $0 } ?? false
            let answer = [IVSolver.Solution(level: nick.level, ivs: nick.ivs, distance: 0)]
            if hpOK && dustOK && cpOK { return (answer, .matched) }
            if hpOK && dustOK && reading.hp != nil { return (answer, .usedWithoutCP) }
        }
        guard let cp = reading.cp else { return ([], nick == nil ? .none : .ignored) }
        var solutions = IVSolver.solve(base: base, cp: cp, hp: reading.hp, powerUpStardust: powerUpStardust,
                                       modifiers: modifiers, hints: barHints, tables: tables)
        // Bars misread? Fall back to no IV hints rather than nothing.
        if solutions.isEmpty && !barHints.isEmpty {
            solutions = IVSolver.solve(base: base, cp: cp, hp: reading.hp, powerUpStardust: powerUpStardust,
                                       modifiers: modifiers, tables: tables)
        }
        return (solutions, nick == nil ? .none : .ignored)
    }

    /// Species that could be on the screen. The name may be a nickname, and regional forms share a
    /// name ("Meowth" can be Galarian), so: every released, non-shadow, non-mega entry whose name
    /// (before any "(form)") is the screen name; else the candy family's evolution line. Filtered by
    /// the type labels when they were read.
    static func candidates(_ reading: ScreenReading, gamemaster: Gamemaster, lookup: GamemasterLookup) -> [GMPokemon] {
        let regular = gamemaster.pokemon.filter { p in
            !p.tags.contains("shadow") && !p.speciesId.hasSuffix("_shadow") && !p.tags.contains("mega")
                && !p.speciesId.contains("_mega") && !p.speciesId.contains("_primal")
        }
        func baseName(_ p: GMPokemon) -> String {
            let name = p.speciesName
            guard let open = name.firstIndex(of: "(") else { return name.lowercased() }
            return name[..<open].trimmingCharacters(in: .whitespaces).lowercased()
        }
        var found: [GMPokemon] = []
        if let name = reading.name?.lowercased(), !name.isEmpty {
            found = regular.filter { baseName($0) == name || $0.speciesName.lowercased() == name }
            if found.isEmpty, let p = lookup.pokemon(named: name) { found = [p] }
        }
        if found.isEmpty, let family = reading.candyFamily, let root = lookup.pokemon(named: family) {
            let lineIds = Set(lookup.evolutionLine(from: root).map(\.speciesId))
            let familyNames = Set(lookup.evolutionLine(from: root).map(baseName))
            found = regular.filter { lineIds.contains($0.speciesId) || familyNames.contains(baseName($0)) }
        }
        if !reading.types.isEmpty {
            let byType = found.filter { Set($0.realTypes) == Set(reading.types) }
            if !byType.isEmpty { found = byType }
        }
        // Released entries first, then by name; no duplicates.
        var seen: Set<String> = []
        return found.filter { seen.insert($0.speciesId).inserted }
            .sorted { ($0.released ? 0 : 1, $0.speciesName) < ($1.released ? 0 : 1, $1.speciesName) }
    }
}
