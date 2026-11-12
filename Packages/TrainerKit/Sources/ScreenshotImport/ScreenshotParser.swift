import Foundation

/// A rectangle in normalised image coordinates: origin top-left, 0…1 on both axes.
public struct TextBox: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

/// One line of text found on a screenshot (by Apple's Vision text recognition in the app).
public struct RecognizedLine: Hashable, Sendable {
    public var text: String
    public var box: TextBox

    public init(_ text: String, _ box: TextBox) {
        self.text = text
        self.box = box
    }
}

/// The three appraisal bars.
public enum AppraisalStat: String, CaseIterable, Hashable, Sendable {
    case attack = "Attack"
    case defense = "Defense"
    case hp = "HP"
}

/// What could be read from one screenshot of a Pokémon's screen (any value may be missing).
public struct ScreenReading: Hashable, Sendable {
    public var cp: Int?
    /// Maximum HP ("129 / 129 HP" gives 129).
    public var hp: Int?
    /// The big name under the Pokémon: the species, or a nickname.
    public var name: String?
    /// "EEVEE CANDY" gives "Eevee": the evolution family.
    public var candyFamily: String?
    /// Type names shown under the name, lowercased ("ice", or "dragon" and "flying").
    public var types: [String] = []
    /// Stardust and candy for the next power-up (the POWER UP button row).
    public var powerUpStardust: Int?
    public var powerUpCandy: Int?
    /// Lines below the "GYMS & RAIDS" tab (or the power-up row): where the moves are.
    public var moveLines: [String] = []
    /// A PURIFY button is shown: a shadow Pokémon.
    public var isShadow = false
    /// The word LUCKY is shown.
    public var isLucky = false
    /// Where the appraisal labels are, so the app can measure the bars under them.
    public var appraisalLabels: [AppraisalStat: TextBox] = [:]

    public init() {}

    /// Values from `other` fill in what this reading is missing (screenshots of one Pokémon combined).
    public func merged(with other: ScreenReading) -> ScreenReading {
        var r = self
        r.cp = cp ?? other.cp
        r.hp = hp ?? other.hp
        r.name = name ?? other.name
        r.candyFamily = candyFamily ?? other.candyFamily
        if r.types.isEmpty { r.types = other.types }
        r.powerUpStardust = powerUpStardust ?? other.powerUpStardust
        r.powerUpCandy = powerUpCandy ?? other.powerUpCandy
        r.moveLines += other.moveLines
        r.isShadow = isShadow || other.isShadow
        r.isLucky = isLucky || other.isLucky
        for (k, v) in other.appraisalLabels where r.appraisalLabels[k] == nil { r.appraisalLabels[k] = v }
        return r
    }
}

/// Reads the English Pokémon screen and appraisal screen from recognised text lines.
///
/// Layout assumptions (from real screenshots of the English game UI): CP is the big number near
/// the top centre, "<current> / <max> HP" sits under the name, the next power-up's stardust and
/// candy are on the POWER UP row, and moves are listed under the "GYMS & RAIDS" tab.
public enum ScreenshotParser {
    /// The 18 type names, for reading the type labels.
    static let typeNames: Set<String> = ["normal", "fire", "water", "grass", "electric", "ice", "fighting", "poison", "ground",
                                         "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]

    public static func parse(_ lines: [RecognizedLine]) -> ScreenReading {
        var r = ScreenReading()
        r.cp = cp(in: lines)

        // "129 / 129 HP" -> 129 (the maximum).
        var hpLine: RecognizedLine?
        for line in lines {
            if let m = firstMatch(#"(\d{1,4})\s*/\s*(\d{1,4})\s*HP"#, in: line.text), m.count == 3, let max = Int(m[2]) {
                r.hp = max
                hpLine = line
                break
            }
        }

        // The name: the nearest line above the HP line with letters only.
        if let hpLine {
            let above = lines.filter {
                $0.box.maxY <= hpLine.box.minY + 0.005 && hpLine.box.minY - $0.box.maxY < 0.08
                    && isNameLike($0.text)
            }
            r.name = above.max { $0.box.maxY < $1.box.maxY }.map { cleanedName($0.text) }
        }

        for line in lines {
            let upper = line.text.uppercased()
            // "EEVEE CANDY" (not "EEVEE CANDY XL").
            if upper.hasSuffix(" CANDY"), r.candyFamily == nil {
                let family = String(line.text.dropLast(" CANDY".count)).trimmingCharacters(in: .whitespaces)
                if !family.isEmpty { r.candyFamily = family.capitalized }
            }
            if upper.contains("PURIFY") { r.isShadow = true }
            if upper.trimmingCharacters(in: .whitespaces) == "LUCKY" || upper.contains("LUCKY POK") { r.isLucky = true }
        }

        r.types = types(in: lines, below: hpLine)
        readPowerUpRow(lines, into: &r)
        r.moveLines = moveLines(lines)

        // Appraisal labels are lines that say exactly "Attack", "Defense" or "HP".
        for line in lines {
            let t = line.text.trimmingCharacters(in: .whitespaces).lowercased()
            for stat in AppraisalStat.allCases where t == stat.rawValue.lowercased() && r.appraisalLabels[stat] == nil {
                r.appraisalLabels[stat] = line.box
            }
        }
        return r
    }

    // MARK: - Pieces

    /// The CP: a line near the top centre that is "CP" (or a misread of it) followed by 2-5 digits.
    static func cp(in lines: [RecognizedLine]) -> Int? {
        var best: (value: Int, distance: Double)?
        for line in lines where line.box.midY > 0.03 && line.box.midY < 0.16 {
            let compact = line.text.replacingOccurrences(of: " ", with: "")
            guard let m = firstMatch(#"^[A-Za-z]{0,3}(\d{2,5})$"#, in: compact), m.count == 2, let value = Int(m[1]) else { continue }
            let distance = abs(line.box.midX - 0.5)
            guard distance < 0.3 else { continue }
            if best == nil || distance < best!.distance { best = (value, distance) }
        }
        return best?.value
    }

    /// Type labels such as "ICE" or "DRAGON / FLYING", within a short distance below the HP line.
    static func types(in lines: [RecognizedLine], below hpLine: RecognizedLine?) -> [String] {
        let region = lines.filter { line in
            guard let hp = hpLine else { return true }
            return line.box.minY > hp.box.maxY && line.box.minY - hp.box.maxY < 0.15
        }
        var found: [(String, Double)] = []
        for line in region {
            let words = line.text.lowercased().split { !$0.isLetter }.map(String.init)
            // Only lines that consist of type names (so "Dragon Claw" is not read as a type).
            guard !words.isEmpty, words.allSatisfy({ typeNames.contains($0) }) else { continue }
            for w in words where !found.contains(where: { $0.0 == w }) { found.append((w, line.box.minX)) }
        }
        return Array(found.sorted { $0.1 < $1.1 }.map(\.0).prefix(2))
    }

    static func readPowerUpRow(_ lines: [RecognizedLine], into r: inout ScreenReading) {
        guard let button = lines.first(where: { $0.text.uppercased().replacingOccurrences(of: " ", with: "") == "POWERUP" }) else { return }
        let row = lines.filter {
            $0.box.minX >= button.box.maxX - 0.02 && abs($0.box.midY - button.box.midY) < max(button.box.height, 0.02)
        }.sorted { $0.box.minX < $1.box.minX }
        let numbers = row.flatMap { integers(in: $0.text) }
        guard !numbers.isEmpty else { return }
        // Stardust is the first (left) number, candy the next one.
        r.powerUpStardust = numbers.first
        if numbers.count > 1 { r.powerUpCandy = numbers[1] }
    }

    static func moveLines(_ lines: [RecognizedLine]) -> [String] {
        let header = lines.first { $0.text.uppercased().contains("GYMS") && $0.text.uppercased().contains("RAIDS") }
            ?? lines.first { $0.text.uppercased().replacingOccurrences(of: " ", with: "") == "POWERUP" }
        guard let header else { return [] }
        let end = lines.first {
            $0.box.minY > header.box.maxY && $0.text.uppercased().replacingOccurrences(of: " ", with: "").hasPrefix("NEWATTACK")
        }?.box.minY ?? 1.01
        return lines.filter { $0.box.minY > header.box.maxY && $0.box.maxY <= end + 0.001 }
            .sorted { $0.box.minY < $1.box.minY }
            .map { stripTrailingNoise($0.text) }
            .filter { $0.contains { $0.isLetter } }
    }

    // MARK: - Text helpers

    /// Integers in a text, with thousands separators: "5,000 4" -> [5000, 4].
    static func integers(in text: String) -> [Int] {
        allMatches(#"\d{1,3}(?:[,.]\d{3})+|\d+"#, in: text).compactMap {
            Int($0.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: ""))
        }
    }

    static func isNameLike(_ text: String) -> Bool {
        let t = cleanedName(text)
        return t.count >= 2 && t.contains { $0.isLetter } && !t.contains { $0.isNumber }
    }

    /// Drops the edit pencil and other symbols OCR may attach to the name.
    static func cleanedName(_ text: String) -> String {
        let kept = text.filter { $0.isLetter || $0.isNumber || " .'-♀♂():".contains($0) }
        return kept.trimmingCharacters(in: .whitespaces)
    }

    /// "Icy Wind ▬▬▬" or "Ice Shard 10" -> "Icy Wind" / "Ice Shard".
    static func stripTrailingNoise(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespaces)
        while let last = t.last, !(last.isLetter || last == "+" || last == ")") { t.removeLast() }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }

    static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
}
