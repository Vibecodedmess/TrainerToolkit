import Foundation

/// Turns a `SearchState` into an in-game search string.
///
/// Shape of the result: clauses joined by AND (`&`). A clause is either
/// - one term (`shiny`), one negated term (`!shiny`), or
/// - several included options of the same filter joined by OR (`0*,1*,2*`).
/// Negated terms always get their own clause, so `!` never sits inside an OR list
/// (where its scope would be ambiguous). Example: `0*,1*&!shiny&!lucky`.
public enum SearchQueryBuilder {
    /// Characters with a special meaning in the game's search box. Stripped from free text.
    static let operatorCharacters: Set<Character> = ["&", "|", ",", ":", ";", "!"]

    public static func build(_ state: SearchState, in catalog: SearchCatalog) -> String {
        clauses(for: state, in: catalog).joined(separator: catalog.operators.and)
    }

    public static func clauses(for state: SearchState, in catalog: SearchCatalog) -> [String] {
        let not = catalog.operators.not
        let or = catalog.operators.or
        var result: [String] = []

        for filter in catalog.allFilters {
            switch filter.kind {
            case .flag:
                guard let term = filter.term, let inclusion = state.flags[filter.id] else { continue }
                result.append(inclusion == .include ? term : not + term)

            case .options:
                guard let selected = state.options[filter.id], !selected.isEmpty else { continue }
                let included = filter.options.filter { selected[$0.id] == .include }.map(\.term)
                let excluded = filter.options.filter { selected[$0.id] == .exclude }.map(\.term)
                if !included.isEmpty { result.append(included.joined(separator: or)) }
                result.append(contentsOf: excluded.map { not + $0 })

            case .range:
                guard let range = state.ranges[filter.id],
                      let term = rangeTerm(prefix: filter.prefix ?? "", range: range,
                                           lowerBound: filter.lowerBound, upperBound: filter.upperBound) else { continue }
                result.append(range.inclusion == .include ? term : not + term)

            case .number:
                guard let value = state.numbers[filter.id] else { continue }
                result.append((filter.prefix ?? "") + String(value))

            case .text:
                let prefix = filter.prefix ?? ""
                let entries = (state.texts[filter.id] ?? []).compactMap { entry -> (String, Inclusion)? in
                    let value = sanitize(entry.value, dropping: prefix)
                    return value.isEmpty ? nil : (prefix + value, entry.inclusion)
                }
                let included = entries.filter { $0.1 == .include }.map { $0.0 }
                let excluded = entries.filter { $0.1 == .exclude }.map { $0.0 }
                if !included.isEmpty { result.append(included.joined(separator: or)) }
                result.append(contentsOf: excluded.map { not + $0 })
            }
        }
        return result
    }

    /// "cp100-500", "cp100-" (at least), "cp-500" (at most), "cp300" (exactly). Nil if empty.
    static func rangeTerm(prefix: String, range: RangeValue, lowerBound: Int?, upperBound: Int?) -> String? {
        func clamp(_ value: Int?) -> Int? {
            guard var value else { return nil }
            if let lowerBound { value = Swift.max(value, lowerBound) }
            if let upperBound { value = Swift.min(value, upperBound) }
            return value
        }
        var low = clamp(range.min)
        var high = clamp(range.max)
        if let l = low, let h = high, l > h { (low, high) = (h, l) }

        switch (low, high) {
        case (nil, nil): return nil
        case let (l?, h?) where l == h: return "\(prefix)\(l)"
        case let (l?, h?): return "\(prefix)\(l)-\(h)"
        case let (l?, nil): return "\(prefix)\(l)-"
        case let (nil, h?): return "\(prefix)-\(h)"
        }
    }

    /// Lowercases, trims, collapses spaces, removes operator characters and a prefix the
    /// user typed themselves (so "@scratch" in the move field doesn't become "@@scratch").
    public static func sanitize(_ text: String, dropping prefix: String = "") -> String {
        var value = text.lowercased()
        value.removeAll { operatorCharacters.contains($0) }
        value = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if !prefix.isEmpty {
            while value.hasPrefix(prefix) { value.removeFirst(prefix.count) }
            value = value.trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    /// Notes for every selected term that the help article doesn't confirm.
    public static func unverifiedNotes(for state: SearchState, in catalog: SearchCatalog) -> [String] {
        var notes: [String] = []
        for filter in catalog.allFilters where state.activeCount(for: filter.id) > 0 {
            if !filter.verified {
                notes.append("\(filter.label): \(filter.note ?? "not confirmed by the help article.")")
            }
            let unverifiedOptions = filter.options.filter { !$0.verified && state.options[filter.id]?[$0.id] != nil }
            for option in unverifiedOptions {
                notes.append("\(filter.label) \(option.label): not confirmed by the help article.")
            }
        }
        let built = clauses(for: state, in: catalog)
        let mixesAndOr = built.count > 1 && built.contains { $0.contains(catalog.operators.or) }
        if mixesAndOr {
            notes.append(contentsOf: catalog.operators.notes.filter { !$0.verified }.map(\.text))
        }
        return notes
    }
}
