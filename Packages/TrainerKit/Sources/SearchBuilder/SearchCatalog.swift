import Foundation

/// The list of in-game search terms and operators, loaded from `search-terms.json`.
/// Edit that file (not code) to add, fix or flag terms.
public struct SearchCatalog: Decodable, Sendable {
    public struct Source: Decodable, Sendable {
        public let title: String
        public let url: String
        public let checked: String
    }

    public struct Note: Decodable, Sendable, Hashable {
        public let text: String
        public let verified: Bool
    }

    public struct Operators: Decodable, Sendable {
        public let and: String
        public let andAlternatives: [String]
        public let or: String
        public let orAlternatives: [String]
        public let not: String
        public let notes: [Note]
    }

    public enum Kind: String, Decodable, Sendable {
        /// One keyword, e.g. "shiny". Include or exclude.
        case flag
        /// A set of keywords, e.g. star appraisals. Included ones are OR-ed.
        case options
        /// prefix + number range, e.g. "cp100-500".
        case range
        /// prefix + single number, e.g. "year2016".
        case number
        /// prefix + free text, e.g. "+pikachu", "@scratch", "#battle".
        case text
    }

    public struct Option: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let label: String
        public let term: String
        public let verified: Bool

        enum CodingKeys: String, CodingKey { case id, label, term, verified }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            label = try c.decode(String.self, forKey: .label)
            term = try c.decode(String.self, forKey: .term)
            verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? true
        }
    }

    public struct Filter: Decodable, Sendable, Identifiable {
        public let id: String
        public let kind: Kind
        public let label: String
        public let term: String?
        public let prefix: String?
        public let options: [Option]
        public let lowerBound: Int?
        public let upperBound: Int?
        public let placeholder: String?
        public let note: String?
        public let verified: Bool

        enum CodingKeys: String, CodingKey {
            case id, kind, label, term, prefix, options, lowerBound, upperBound, placeholder, note, verified
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            kind = try c.decode(Kind.self, forKey: .kind)
            label = try c.decode(String.self, forKey: .label)
            term = try c.decodeIfPresent(String.self, forKey: .term)
            prefix = try c.decodeIfPresent(String.self, forKey: .prefix)
            options = try c.decodeIfPresent([Option].self, forKey: .options) ?? []
            lowerBound = try c.decodeIfPresent(Int.self, forKey: .lowerBound)
            upperBound = try c.decodeIfPresent(Int.self, forKey: .upperBound)
            placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
            note = try c.decodeIfPresent(String.self, forKey: .note)
            verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? true
        }
    }

    public struct Group: Decodable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let filters: [Filter]
    }

    public struct Preset: Decodable, Sendable, Identifiable {
        public let name: String
        public let summary: String?
        public let state: SearchState
        public var id: String { name }
    }

    public let version: Int
    public let source: Source
    public let operators: Operators
    public let groups: [Group]
    public let presets: [Preset]

    public var allFilters: [Filter] { groups.flatMap(\.filters) }

    public func filter(id: String) -> Filter? {
        allFilters.first { $0.id == id }
    }

    /// The catalog that ships in the app.
    public static func bundled() throws -> SearchCatalog {
        guard let url = Bundle.module.url(forResource: "search-terms", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(SearchCatalog.self, from: Data(contentsOf: url))
    }
}
