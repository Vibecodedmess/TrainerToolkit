import SwiftUI
import GameMath
import DataSources

/// Bundled evolution data (PokeMiners game master + game text) and the community "how to get" guide.
enum EvolutionData {
    static let tables: EvolutionTables? = try? EvolutionTables.bundled()
    static let guide: EvolutionItemGuide? = try? EvolutionItemGuide.bundled()

    /// Items and lures a species needs to evolve, by name ("Metal Coat"), in data order, no repeats.
    static func itemNames(forSpecies speciesId: String) -> [String] {
        guard let tables else { return [] }
        var names: [String] = []
        for b in tables.branches(forSpecies: speciesId) {
            for id in [b.item, b.lure].compactMap({ $0 }) {
                let name = tables.item(id)?.name ?? id
                if !names.contains(name) { names.append(name) }
            }
        }
        return names
    }

    /// Display name of an evolution target, via PvPoke's names when possible.
    static func targetName(_ b: EvolutionTables.Branch, lookup: GamemasterLookup?) -> String {
        if let p = lookup?.pokemon(id: b.targetKey) ?? lookup?.pokemon(id: b.evolution.lowercased()) { return p.speciesName }
        return b.evolution.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// "Evolution" section for a Pokémon in My Collection: what it can evolve into and what that needs.
struct EvolutionSection: View {
    let speciesId: String
    let isPurified: Bool
    let lookup: GamemasterLookup?

    var body: some View {
        if let tables = EvolutionData.tables {
            let branches = tables.branches(forSpecies: speciesId)
            if !branches.isEmpty {
                Section {
                    ForEach(Array(branches.enumerated()), id: \.offset) { _, b in
                        branchView(b, tables: tables)
                    }
                } header: {
                    Text("Evolution")
                } footer: {
                    Text("Requirements from the game master (PokeMiners). Tap an item to see how to get it.")
                }
            }
        }
    }

    @ViewBuilder
    private func branchView(_ b: EvolutionTables.Branch, tables: EvolutionTables) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(EvolutionData.targetName(b, lookup: lookup), systemImage: "arrow.right.circle")
                    .font(.headline)
                Spacer()
                if let candy = candyCost(b) {
                    Text(candy == 0 ? "No candy" : "\(candy) candy")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(requirements(b, tables: tables), id: \.self) { line in
                Label(line.text, systemImage: line.symbol)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
        ForEach([b.item, b.lure].compactMap { $0 }, id: \.self) { id in
            if let item = tables.item(id) {
                NavigationLink {
                    EvolutionItemView(item: item, guideText: EvolutionData.guide?.howToGet(id), guide: EvolutionData.guide?.source)
                } label: {
                    Label("How to get \(item.name)", systemImage: "questionmark.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    private func candyCost(_ b: EvolutionTables.Branch) -> Int? {
        if isPurified, let purified = b.candyCostPurified { return purified }
        return b.candyCost
    }

    struct Requirement: Hashable {
        let text: String
        let symbol: String
    }

    private func requirements(_ b: EvolutionTables.Branch, tables: EvolutionTables) -> [Requirement] {
        var r: [Requirement] = []
        if let id = b.item {
            let name = tables.item(id)?.name ?? id
            r.append(Requirement(text: (b.itemCost.map { $0 > 1 ? "\($0) × \(name)" : name } ?? name), symbol: "shippingbox"))
        }
        if let id = b.lure {
            r.append(Requirement(text: "Near a PokéStop with a \(tables.item(id)?.name ?? id)", symbol: "mappin.circle"))
        }
        if let q = b.quest {
            r.append(Requirement(text: tables.quest(q)?.text ?? "Complete its evolution quest", symbol: "checklist"))
        }
        if let km = b.kmBuddyDistance {
            r.append(Requirement(text: "Walk \(km.formatted()) km with it as your buddy", symbol: "figure.walk"))
        } else if b.mustBeBuddy {
            r.append(Requirement(text: "Must be your buddy", symbol: "person.2"))
        }
        if b.onlyDaytime { r.append(Requirement(text: "Only during the day", symbol: "sun.max")) }
        if b.onlyNighttime { r.append(Requirement(text: "Only at night", symbol: "moon")) }
        if b.onlyDusk { r.append(Requirement(text: "Only at dusk", symbol: "sunset")) }
        if b.onlyFullMoon { r.append(Requirement(text: "Only during a full moon", symbol: "moon.circle")) }
        if b.onlyUpsideDown { r.append(Requirement(text: "Hold your phone upside down", symbol: "iphone")) }
        if let g = b.gender {
            r.append(Requirement(text: g == "MALE" ? "Only male Pokémon" : g == "FEMALE" ? "Only female Pokémon" : "Gender: \(g.capitalized)",
                                 symbol: "person"))
        }
        if b.noCandyCostViaTrade { r.append(Requirement(text: "No candy needed if it was traded", symbol: "arrow.left.arrow.right")) }
        return r
    }
}

/// One evolution item: the game's name and description, and the community "how to get" text.
struct EvolutionItemView: View {
    let item: EvolutionTables.Item
    let guideText: String?
    let guide: EvolutionItemGuide.Source?

    var body: some View {
        Form {
            if let description = item.description, !description.isEmpty {
                Section("In the game") {
                    Text(description)
                }
            }
            Section {
                if let guideText {
                    Text(guideText)
                } else {
                    Text("No information.").foregroundStyle(.secondary)
                }
            } header: {
                Text("How to get it")
            } footer: {
                if let guide {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Community information from the \(guide.name) (\(guide.license)), retrieved \(guide.retrieved). Not verified: methods change with events and updates.")
                        ForEach(guide.pages, id: \.self) { page in
                            if let url = URL(string: page) {
                                Link(page, destination: url)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
