import Foundation

public enum Inclusion: String, Codable, Sendable, CaseIterable {
    case include
    case exclude
}

public struct RangeValue: Codable, Sendable, Hashable {
    public var min: Int?
    public var max: Int?
    public var inclusion: Inclusion

    public init(min: Int? = nil, max: Int? = nil, inclusion: Inclusion = .include) {
        self.min = min
        self.max = max
        self.inclusion = inclusion
    }

    enum CodingKeys: String, CodingKey { case min, max, inclusion }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        min = try c.decodeIfPresent(Int.self, forKey: .min)
        max = try c.decodeIfPresent(Int.self, forKey: .max)
        inclusion = try c.decodeIfPresent(Inclusion.self, forKey: .inclusion) ?? .include
    }

    public var isEmpty: Bool { min == nil && max == nil }
}

public struct TextEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var value: String
    public var inclusion: Inclusion

    public init(value: String, inclusion: Inclusion = .include) {
        id = UUID()
        self.value = value
        self.inclusion = inclusion
    }

    enum CodingKeys: String, CodingKey { case id, value, inclusion }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        value = try c.decode(String.self, forKey: .value)
        inclusion = try c.decodeIfPresent(Inclusion.self, forKey: .inclusion) ?? .include
    }
}

/// Everything selected in the builder. Keys are filter ids from `search-terms.json`.
/// Codable, so presets can be saved and defined in the JSON file.
public struct SearchState: Codable, Sendable, Hashable {
    public var flags: [String: Inclusion]
    /// filter id -> option id -> inclusion
    public var options: [String: [String: Inclusion]]
    public var ranges: [String: RangeValue]
    public var numbers: [String: Int]
    public var texts: [String: [TextEntry]]

    public init() {
        flags = [:]
        options = [:]
        ranges = [:]
        numbers = [:]
        texts = [:]
    }

    enum CodingKeys: String, CodingKey { case flags, options, ranges, numbers, texts }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flags = try c.decodeIfPresent([String: Inclusion].self, forKey: .flags) ?? [:]
        options = try c.decodeIfPresent([String: [String: Inclusion]].self, forKey: .options) ?? [:]
        ranges = try c.decodeIfPresent([String: RangeValue].self, forKey: .ranges) ?? [:]
        numbers = try c.decodeIfPresent([String: Int].self, forKey: .numbers) ?? [:]
        texts = try c.decodeIfPresent([String: [TextEntry]].self, forKey: .texts) ?? [:]
    }

    public var isEmpty: Bool {
        flags.isEmpty
            && options.values.allSatisfy(\.isEmpty)
            && ranges.values.allSatisfy(\.isEmpty)
            && numbers.isEmpty
            && texts.values.allSatisfy(\.isEmpty)
    }

    /// Number of active selections for one filter (for summary badges).
    public func activeCount(for filterID: String) -> Int {
        var count = 0
        if flags[filterID] != nil { count += 1 }
        count += options[filterID]?.count ?? 0
        if let range = ranges[filterID], !range.isEmpty { count += 1 }
        if numbers[filterID] != nil { count += 1 }
        count += texts[filterID]?.count ?? 0
        return count
    }
}
