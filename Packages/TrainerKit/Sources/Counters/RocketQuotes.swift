import Foundation

/// What Team GO Rocket members say before a battle, from the game's own English text (PokeMiners
/// pogo_assets, extracted by scripts/update-rocket-quotes.ps1). A grunt's line gives away its type.
public struct RocketQuotes: Decodable, Sendable {
    public struct Source: Decodable, Sendable, Hashable {
        public let name: String
        public let url: String
        public let commit: String
        public let extracted: String
    }

    public let source: Source
    /// Grunt type ("fire") -> line.
    public let typed: [String: String]
    /// Lines of grunts without a type (one of these is said).
    public let generic: [String]
    /// "giovanni", "cliff", "arlo", "sierra" -> line.
    public let leaders: [String: String]

    public static func bundled() throws -> RocketQuotes {
        guard let url = Bundle.module.url(forResource: "rocket-quotes", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(RocketQuotes.self, from: Data(contentsOf: url))
    }

    /// The lines a lineup from the feed can say: its type's line for typed grunts, the leader's line
    /// for leaders and Giovanni, the generic lines for grunts without a type. Empty when the game
    /// text has nothing for it (for example the Decoy Grunt).
    public func lines(name: String, type: String?, title: String?) -> [String] {
        let lowerName = name.lowercased()
        if let type, !type.isEmpty {
            return typed[type.lowercased()].map { [$0] } ?? []
        }
        for (leader, line) in leaders where lowerName.split(separator: " ").contains(Substring(leader)) || lowerName == leader {
            return [line]
        }
        if lowerName.contains("decoy") { return [] }
        let isGrunt = lowerName.contains("grunt") || (title?.lowercased().contains("grunt") ?? false)
        return isGrunt ? generic : []
    }

    // MARK: - Search

    /// Lowercased, without accents and punctuation, single spaces: "Don’t tangle with us!" -> "dont tangle with us".
    /// So a search typed with a plain apostrophe (or none) still finds the game's curly one.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let kept = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar == "-" || scalar == "—" || scalar == "." { return " " }
            return "\u{0}" // dropped: apostrophes, quotes, other punctuation
        }.filter { $0 != "\u{0}" }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// True when every word of the query appears in the text (after `normalize`), in any order.
    public static func matches(_ query: String, in text: String) -> Bool {
        let words = normalize(query).split(separator: " ")
        guard !words.isEmpty else { return true }
        let haystack = normalize(text)
        return words.allSatisfy { haystack.contains($0) }
    }
}
