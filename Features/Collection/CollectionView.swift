import SwiftUI
import SwiftData
import GameMath
import DataSources

struct CollectionView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case recent = "Recently added"
        case cp = "CP"
        case iv = "IV %"
        case name = "Name"
        var id: String { rawValue }
    }

    @Query(sort: \CollectedPokemon.createdAt, order: .reverse) private var all: [CollectedPokemon]
    @Environment(\.modelContext) private var modelContext
    @Environment(DataCenter.self) private var dataCenter
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var showingScreenshots = false
    @AppStorage("collection.sort") private var sortRaw = SortOrder.recent.rawValue
    @AppStorage("collection.onlyShiny") private var onlyShiny = false
    @AppStorage("collection.onlyShadow") private var onlyShadow = false
    @AppStorage("collection.onlyLucky") private var onlyLucky = false
    @AppStorage("collection.onlyPurified") private var onlyPurified = false
    @AppStorage("collection.type") private var typeFilter = ""

    private var sort: SortOrder { SortOrder(rawValue: sortRaw) ?? .recent }
    private var filtersActive: Bool { onlyShiny || onlyShadow || onlyLucky || onlyPurified || !typeFilter.isEmpty }

    var body: some View {
        Group {
            if all.isEmpty {
                ContentUnavailableView {
                    Label("Your collection is empty", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Add the Pokémon you use for raids and battles. They're used for counter suggestions later.")
                } actions: {
                    Button("Add Pokémon") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                    Button("Add from screenshots") { showingScreenshots = true }
                    Button("Import from CSV") { showingImport = true }
                }
            } else {
                list
            }
        }
        .navigationTitle("Collection")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu
                Menu {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                    }
                    Button {
                        showingScreenshots = true
                    } label: {
                        Label("From screenshots", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Add Pokémon", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                CollectionEditorView(pokemon: nil)
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
        .sheet(isPresented: $showingScreenshots) {
            NavigationStack {
                ScreenshotImportView()
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                CollectionImportView()
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
    }

    private var list: some View {
        let tables = PlannerMath.tables
        let shown = filtered(tables)
        return List {
            if filtersActive {
                Section {
                    Button("Clear filters") {
                        onlyShiny = false; onlyShadow = false; onlyLucky = false; onlyPurified = false; typeFilter = ""
                    }
                } footer: {
                    Text("Showing \(shown.count) of \(all.count).")
                }
            }
            ForEach(shown) { pokemon in
                NavigationLink {
                    CollectionEditorView(pokemon: pokemon)
                } label: {
                    CollectionRow(pokemon: pokemon, tables: tables, lookup: dataCenter.lookup)
                }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(shown[index]) }
                try? modelContext.save()
            }
        }
        .searchable(text: $search, prompt: "Name, nickname or move")
        .overlay {
            if shown.isEmpty {
                if search.isEmpty {
                    ContentUnavailableView("Nothing matches the filters", systemImage: "line.3.horizontal.decrease.circle")
                } else {
                    ContentUnavailableView.search(text: search)
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortRaw) {
                ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Section("Only show") {
                Toggle("Shiny", isOn: $onlyShiny)
                Toggle("Shadow", isOn: $onlyShadow)
                Toggle("Purified", isOn: $onlyPurified)
                Toggle("Lucky", isOn: $onlyLucky)
            }
            Picker("Type", selection: $typeFilter) {
                Text("Any type").tag("")
                ForEach(Self.allTypes, id: \.self) { Text($0.capitalized).tag($0) }
            }
        } label: {
            Label("Filter and sort", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    /// The 18 type names as used in PvPoke's data (for the filter menu).
    static let allTypes = ["normal", "fire", "water", "grass", "electric", "ice", "fighting", "poison", "ground",
                           "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]

    private func filtered(_ tables: LevelTables?) -> [CollectedPokemon] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let lookup = dataCenter.lookup
        var result = all.filter { p in
            if onlyShiny && !p.isShiny { return false }
            if onlyShadow && !p.isShadow { return false }
            if onlyLucky && !p.isLucky { return false }
            if onlyPurified && !p.isPurified { return false }
            if !typeFilter.isEmpty {
                guard let types = lookup?.pokemon(id: p.speciesId)?.realTypes, types.contains(typeFilter) else { return false }
            }
            guard !query.isEmpty else { return true }
            let moveNames = ([p.fastMoveId] + p.chargedMoveIds).filter { !$0.isEmpty }.map { lookup?.moveName($0) ?? $0 }
            let haystack = ([p.speciesName, p.nickname, p.notes] + moveNames).joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
        switch sort {
        case .recent: break
        case .cp:
            if let tables { result.sort { ($0.cp(tables) ?? 0) > ($1.cp(tables) ?? 0) } }
        case .iv:
            result.sort { $0.ivs.percent > $1.ivs.percent }
        case .name:
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        return result
    }
}

private struct CollectionRow: View {
    let pokemon: CollectedPokemon
    let tables: LevelTables?
    let lookup: GamemasterLookup?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(pokemon.displayName)
                    .font(.headline)
                    .lineLimit(1)
                flagIcons
                Spacer()
                if let types = lookup?.pokemon(id: pokemon.speciesId)?.realTypes {
                    TypeBadges(types: types)
                }
            }
            Text(statsLine)
                .font(.subheadline)
            if !movesLine.isEmpty {
                Text(movesLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            let evolutionItems = EvolutionData.itemNames(forSpecies: pokemon.speciesId)
            if !evolutionItems.isEmpty {
                Label("Evolves with \(evolutionItems.joined(separator: " or "))", systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var statsLine: String {
        var parts: [String] = []
        if let tables, let cp = pokemon.cp(tables) { parts.append("CP \(cp)") }
        parts.append("L\(pokemon.level.description)")
        parts.append("\(pokemon.ivAttack)/\(pokemon.ivDefense)/\(pokemon.ivStamina) (\(pokemon.ivs.percent)%)")
        return parts.joined(separator: " · ")
    }

    private var movesLine: String {
        let fast = pokemon.fastMoveId.isEmpty ? nil : lookup?.moveName(pokemon.fastMoveId) ?? pokemon.fastMoveId
        let charged = pokemon.chargedMoveIds.map { lookup?.moveName($0) ?? $0 }
        return ([fast].compactMap { $0 } + charged).joined(separator: " · ")
    }

    @ViewBuilder
    private var flagIcons: some View {
        if pokemon.isShiny {
            Image(systemName: "sparkles").foregroundStyle(.yellow).accessibilityLabel("Shiny")
        }
        if pokemon.isShadow {
            Image(systemName: "flame.fill").foregroundStyle(.purple).accessibilityLabel("Shadow")
        }
        if pokemon.isPurified {
            Image(systemName: "sun.max.fill").foregroundStyle(.cyan).accessibilityLabel("Purified")
        }
        if pokemon.isLucky {
            Image(systemName: "star.fill").foregroundStyle(.orange).accessibilityLabel("Lucky")
        }
    }
}

#Preview {
    NavigationStack { CollectionView() }
        .environment(DataCenter())
        .modelContainer(for: [CollectedPokemon.self], inMemory: true)
}
