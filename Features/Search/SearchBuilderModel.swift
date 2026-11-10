import Foundation
import Observation
import SearchBuilder

/// State behind the Search tab: the term catalog, the current selection and the result.
@MainActor
@Observable
final class SearchBuilderModel {
    let catalog: SearchCatalog?
    let loadError: String?
    var state = SearchState()

    private static let draftKey = "search.draft"

    init() {
        do {
            catalog = try SearchCatalog.bundled()
            loadError = nil
        } catch {
            catalog = nil
            loadError = "The search term list could not be read (\(error.localizedDescription))."
        }
        if let data = UserDefaults.standard.data(forKey: Self.draftKey),
           let saved = try? JSONDecoder().decode(SearchState.self, from: data) {
            state = saved
        }
    }

    var query: String {
        guard let catalog else { return "" }
        return SearchQueryBuilder.build(state, in: catalog)
    }

    /// Explanations for selected terms the help article doesn't confirm.
    var unverifiedNotes: [String] {
        guard let catalog else { return [] }
        return SearchQueryBuilder.unverifiedNotes(for: state, in: catalog)
    }

    func clear() {
        state = SearchState()
    }

    func apply(_ preset: SearchState) {
        state = preset
    }

    /// Remembers the current selection so it's still there next time the app opens.
    func saveDraft() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        }
    }

    // MARK: - Selection helpers used by the rows

    func flag(_ id: String) -> Inclusion? {
        state.flags[id]
    }

    func setFlag(_ id: String, _ value: Inclusion?) {
        state.flags[id] = value
    }

    func option(_ filterID: String, _ optionID: String) -> Inclusion? {
        state.options[filterID]?[optionID]
    }

    func setOption(_ filterID: String, _ optionID: String, _ value: Inclusion?) {
        var picks = state.options[filterID] ?? [:]
        picks[optionID] = value
        state.options[filterID] = picks.isEmpty ? nil : picks
    }

    func rangeBound(_ filterID: String, upper: Bool) -> Int? {
        let range = state.ranges[filterID]
        return upper ? range?.max : range?.min
    }

    func setRangeBound(_ filterID: String, upper: Bool, _ value: Int?) {
        var range = state.ranges[filterID] ?? RangeValue()
        if upper { range.max = value } else { range.min = value }
        state.ranges[filterID] = range.isEmpty ? nil : range
    }

    func setNumber(_ filterID: String, _ value: Int?) {
        state.numbers[filterID] = value
    }

    func entries(_ filterID: String) -> [TextEntry] {
        state.texts[filterID] ?? []
    }

    func setEntries(_ filterID: String, _ entries: [TextEntry]) {
        state.texts[filterID] = entries.isEmpty ? nil : entries
    }

    /// Short description of a filter's current selection for its row, or nil if unused.
    func summary(for filter: SearchCatalog.Filter) -> String? {
        switch filter.kind {
        case .options:
            let picks = state.options[filter.id] ?? [:]
            let yes = filter.options.filter { picks[$0.id] == .include }.map(\.label)
            let no = filter.options.filter { picks[$0.id] == .exclude }.map { "not \($0.label)" }
            let parts = [yes.joined(separator: ", "), no.joined(separator: ", ")].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .text:
            let prefix = filter.prefix ?? ""
            let list = entries(filter.id).map { entry in
                (entry.inclusion == .exclude ? "not " : "") + prefix + SearchQueryBuilder.sanitize(entry.value, dropping: prefix)
            }
            return list.isEmpty ? nil : list.joined(separator: ", ")
        case .flag, .range, .number:
            return nil
        }
    }
}
