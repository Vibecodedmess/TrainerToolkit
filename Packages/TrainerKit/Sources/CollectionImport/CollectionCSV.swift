import Foundation
import DataSources
import GameMath

/// Trainer Toolkit's own collection CSV format (documented in COLLECTION_IMPORT.md).
///
/// Required columns: Name, Attack, Defense, HP, and CP or Level.
/// Optional: Fast move, Charged move, Second charged move, Shadow, Purified, Shiny, Lucky, Nickname, Notes.
/// Header names are matched ignoring case, spaces and punctuation; a few aliases are accepted.
public enum CollectionCSV {
    public enum Column: String, CaseIterable, Sendable {
        case name, cp, level, attack, defense, hp
        case fastMove, chargedMove, secondChargedMove
        case shadow, purified, shiny, lucky, nickname, notes

        /// Header written in the template.
        public var header: String {
            switch self {
            case .name: return "Name"
            case .cp: return "CP"
            case .level: return "Level"
            case .attack: return "Attack"
            case .defense: return "Defense"
            case .hp: return "HP"
            case .fastMove: return "Fast move"
            case .chargedMove: return "Charged move"
            case .secondChargedMove: return "Second charged move"
            case .shadow: return "Shadow"
            case .purified: return "Purified"
            case .shiny: return "Shiny"
            case .lucky: return "Lucky"
            case .nickname: return "Nickname"
            case .notes: return "Notes"
            }
        }

        /// Other accepted header spellings.
        var aliases: [String] {
            switch self {
            case .name: return ["Pokemon", "Pokémon", "Species"]
            case .cp: return ["Combat Power"]
            case .level: return ["Lvl"]
            case .attack: return ["Atk", "Attack IV", "Atk IV"]
            case .defense: return ["Def", "Defense IV", "Defence", "Def IV"]
            case .hp: return ["Sta", "Stamina", "HP IV", "Sta IV"]
            case .fastMove: return ["Fast", "Quick move", "Fast attack", "Quick"]
            case .chargedMove: return ["Charged", "Charged move 1", "Charge move", "Charged attack"]
            case .secondChargedMove: return ["Charged move 2", "Second move", "Charged 2"]
            default: return []
            }
        }
    }

    /// Header line for the template file, in the order shown in the docs.
    public static let templateHeader: String = [Column.name, .cp, .attack, .defense, .hp, .fastMove, .chargedMove,
                                                .secondChargedMove, .shadow, .purified, .shiny, .lucky, .level,
                                                .nickname, .notes].map(\.header).joined(separator: ",")

    public struct Row: Equatable, Sendable {
        /// Line number in the file (header = 1).
        public let line: Int
        public var name: String
        public var cp: Int?
        public var level: Double?
        public var ivs: IVs
        public var fastMove: String?
        public var chargedMove: String?
        public var secondChargedMove: String?
        public var shadow = false
        public var purified = false
        public var shiny = false
        public var lucky = false
        public var nickname = ""
        public var notes = ""
    }

    public struct Problem: Equatable, Sendable, Identifiable {
        public let line: Int
        public let message: String
        public var id: String { "\(line):\(message)" }
    }

    public struct Parsed: Sendable {
        public var rows: [Row] = []
        public var problems: [Problem] = []
        /// Required columns that are missing from the header (nothing can be imported then).
        public var missingColumns: [String] = []
    }

    // MARK: - Parsing

    public static func parse(_ table: CSVTable) -> Parsed {
        var result = Parsed()
        var index: [Column: Int] = [:]
        for column in Column.allCases {
            if let i = ([column.header] + column.aliases).lazy.compactMap({ table.column($0) }).first {
                index[column] = i
            }
        }
        for column in [Column.name, .attack, .defense, .hp] where index[column] == nil {
            result.missingColumns.append(column.header)
        }
        if index[.cp] == nil && index[.level] == nil { result.missingColumns.append("CP (or Level)") }
        guard result.missingColumns.isEmpty else { return result }

        for (offset, raw) in table.rows.enumerated() {
            let line = offset + 2
            func text(_ c: Column) -> String? { table.value(raw, index[c]) }
            guard let name = text(.name) else {
                if raw.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    result.problems.append(Problem(line: line, message: "Name is empty."))
                }
                continue
            }
            var errors: [String] = []
            func iv(_ c: Column) -> Int {
                guard let value = CSVReader.number(text(c)), value == value.rounded(), IVs.range.contains(Int(value)) else {
                    errors.append("\(c.header) must be a whole number from 0 to 15.")
                    return 0
                }
                return Int(value)
            }
            let ivs = IVs(attack: iv(.attack), defense: iv(.defense), stamina: iv(.hp))

            var cp: Int?
            if let cpText = text(.cp) {
                if let v = CSVReader.number(cpText), v >= 10, v == v.rounded() { cp = Int(v) } else { errors.append("CP must be a whole number of at least 10.") }
            }
            var level: Double?
            if let levelText = text(.level) {
                if let v = CSVReader.number(levelText), (v * 2).rounded() == v * 2, v >= 1 { level = v } else { errors.append("Level must be a number like 30 or 30.5.") }
            }
            if cp == nil && level == nil && errors.isEmpty { errors.append("Give the CP (or the Level).") }

            func flag(_ c: Column) -> Bool {
                guard let t = text(c) else { return false }
                switch t.lowercased() {
                case "yes", "y", "true", "1", "x", "ja", "j", "✓", "✔": return true
                case "no", "n", "false", "0", "-", "nee": return false
                default:
                    errors.append("\(c.header) should be yes or no (got \"\(t)\").")
                    return false
                }
            }
            var row = Row(line: line, name: name, cp: cp, level: level, ivs: ivs,
                          fastMove: text(.fastMove), chargedMove: text(.chargedMove), secondChargedMove: text(.secondChargedMove))
            row.shadow = flag(.shadow)
            row.purified = flag(.purified)
            row.shiny = flag(.shiny)
            row.lucky = flag(.lucky)
            row.nickname = text(.nickname) ?? ""
            row.notes = text(.notes) ?? ""

            if errors.isEmpty {
                result.rows.append(row)
            } else {
                result.problems.append(Problem(line: line, message: "\(name): " + errors.joined(separator: " ")))
            }
        }
        return result
    }

    // MARK: - Resolving names, moves and levels

    public struct Candidate: Sendable, Identifiable, Equatable {
        public var id: Int { line }
        public let line: Int
        public let speciesId: String
        public let speciesName: String
        public let types: [String]
        public let base: BaseStats
        public let level: PokemonLevel
        public let ivs: IVs
        public let fastMoveId: String
        public let chargedMoveId: String
        public let secondChargedMoveId: String
        public let isShadow: Bool
        public let isPurified: Bool
        public let isShiny: Bool
        public let isLucky: Bool
        public let nickname: String
        public let notes: String
        /// Things that were adjusted or look odd but didn't stop the import.
        public let warnings: [String]
    }

    public struct Resolved: Sendable {
        public var candidates: [Candidate] = []
        public var problems: [Problem] = []
    }

    public static func resolve(_ parsed: Parsed, lookup: GamemasterLookup, levels: LevelTables) -> Resolved {
        var result = Resolved()
        result.problems = parsed.problems
        for row in parsed.rows {
            var warnings: [String] = []
            var isShadow = row.shadow

            // "Shadow Bulbasaur" / "Bulbasaur (Shadow)" count as Shadow too.
            var name = row.name
            for marker in ["(Shadow)", "(shadow)"] where name.contains(marker) {
                name = name.replacingOccurrences(of: marker, with: "").trimmingCharacters(in: .whitespaces)
                isShadow = true
            }
            if name.lowercased().hasPrefix("shadow ") {
                name = String(name.dropFirst("shadow ".count))
                isShadow = true
            }
            guard var pokemon = lookup.pokemon(named: name) ?? lookup.pokemon(named: row.name) else {
                result.problems.append(Problem(line: row.line, message: "\(row.name): no Pokémon with this name in the data. Use the English name, e.g. \"Galarian Meowth\"."))
                continue
            }
            if pokemon.tags.contains("shadow") || pokemon.speciesId.hasSuffix("_shadow") {
                isShadow = true
                pokemon = lookup.regularForm(of: pokemon)
            }
            let isPurified = row.purified
            if isShadow && isPurified {
                warnings.append("Marked both Shadow and Purified; kept Purified.")
                isShadow = false
            }
            var isLucky = row.lucky
            if isShadow && isLucky {
                warnings.append("Shadow Pokémon can't be lucky; Lucky ignored.")
                isLucky = false
            }

            let base = BaseStats(attack: pokemon.baseStats.atk, defense: pokemon.baseStats.def, stamina: pokemon.baseStats.hp)
            let maxLevel = levels.maxBestBuddyLevel

            // Level: from the Level column, else from CP.
            let level: PokemonLevel
            if let given = row.level {
                level = PokemonLevel(given)
                guard level >= PokemonLevel(1), level <= maxLevel else {
                    result.problems.append(Problem(line: row.line, message: "\(row.name): level \(given) is outside 1–\(maxLevel)."))
                    continue
                }
                if let cp = row.cp, CPCalculator.cp(base: base, ivs: row.ivs, level: level, tables: levels) != cp {
                    warnings.append("CP \(cp) doesn't match level \(level) with these IVs; used the level.")
                }
            } else if let cp = row.cp {
                let matches = CPCalculator.levels(matchingCP: cp, base: base, ivs: row.ivs, maxLevel: maxLevel, tables: levels)
                guard let first = matches.first else {
                    result.problems.append(Problem(line: row.line, message: "\(row.name): no level gives CP \(cp) with IVs \(row.ivs.attack)/\(row.ivs.defense)/\(row.ivs.stamina). Check the CP, the IVs and the form."))
                    continue
                }
                level = first
                if matches.count > 1 {
                    warnings.append("CP \(cp) fits levels \(matches.map(\.description).joined(separator: ", ")); used \(first).")
                }
            } else {
                continue // parse() guarantees CP or Level
            }

            // Moves: names or ids; unknown ones are left empty with a warning.
            let options = lookup.moveOptions(for: pokemon)
            let known = Set(options.fast.map(\.id) + options.charged.map(\.id))
            func move(_ text: String?, label: String) -> String {
                guard let text else { return "" }
                // Prefer a move this Pokémon knows: some names are shared ("Aura Wheel", "Air Slash").
                let wanted = text.trimmingCharacters(in: .whitespaces)
                let ownMove = (options.fast + options.charged).first {
                    $0.name.caseInsensitiveCompare(wanted) == .orderedSame || $0.id == wanted.uppercased()
                }
                guard let id = ownMove?.id ?? lookup.moveId(named: text) else {
                    warnings.append("Unknown \(label) \"\(text)\"; left empty.")
                    return ""
                }
                if !known.contains(id) {
                    warnings.append("\(lookup.moveName(id)) isn't in PvPoke's move list for \(pokemon.speciesName); kept anyway.")
                }
                return id
            }
            let fast = move(row.fastMove, label: "fast move")
            let charged = move(row.chargedMove, label: "charged move")
            let second = move(row.secondChargedMove, label: "second charged move")

            result.candidates.append(Candidate(
                line: row.line, speciesId: pokemon.speciesId, speciesName: pokemon.speciesName,
                types: pokemon.realTypes, base: base, level: level, ivs: row.ivs,
                fastMoveId: fast, chargedMoveId: charged, secondChargedMoveId: second,
                isShadow: isShadow, isPurified: isPurified, isShiny: row.shiny, isLucky: isLucky,
                nickname: row.nickname, notes: row.notes, warnings: warnings))
        }
        return result
    }
}
