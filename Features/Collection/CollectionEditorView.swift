import SwiftUI
import SwiftData
import GameMath
import DataSources

/// Add or edit one Pokémon in My Collection.
struct CollectionEditorView: View {
    /// nil = new entry (shown in a sheet with Cancel).
    let pokemon: CollectedPokemon?

    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CollectionDraft
    @State private var cpLookup: Int?
    @State private var confirmDelete = false
    @FocusState private var keyboardFocused: Bool

    init(pokemon: CollectedPokemon?) {
        self.pokemon = pokemon
        _draft = State(initialValue: pokemon.map { CollectionDraft(pokemon: $0, types: []) } ?? CollectionDraft())
    }

    /// A new entry that starts with these values (for example read from screenshots).
    init(prefilled draft: CollectionDraft) {
        pokemon = nil
        _draft = State(initialValue: draft)
    }

    private var tables: LevelTables? { PlannerMath.tables }
    private var gmPokemon: GMPokemon? { draft.speciesId.flatMap { dataCenter.lookup?.pokemon(id: $0) } }

    var body: some View {
        Form {
            pokemonSection
            statsSection
            movesSection
            flagsSection
            Section("Notes") {
                TextField("Optional", text: $draft.notes, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($keyboardFocused)
            }
            if pokemon != nil {
                Section {
                    Button("Delete from collection", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(pokemon == nil ? "Add Pokémon" : draft.speciesName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if pokemon == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(!draft.isComplete || cpPending)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardFocused = false }
            }
        }
        .confirmationDialog("Delete this Pokémon from your collection?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
        .onAppear {
            if draft.types.isEmpty, let p = gmPokemon { draft.types = p.realTypes }
        }
        .onChange(of: draft.isShadow) { _, on in if on { draft.isPurified = false; draft.isLucky = false } }
        .onChange(of: draft.isPurified) { _, on in if on { draft.isShadow = false } }
        .onChange(of: draft.isLucky) { _, on in if on { draft.isShadow = false } }
        // A typed CP that fits exactly one level is applied right away; otherwise the user picks one.
        .onChange(of: cpLookup) { applySingleCPMatch() }
        .onChange(of: draft.ivs) { applySingleCPMatch() }
        .onChange(of: draft.speciesId) { applySingleCPMatch() }
    }

    // MARK: - CP lookup

    private func levelsMatchingCP(_ tables: LevelTables) -> [PokemonLevel]? {
        guard let cp = cpLookup, let base = draft.base else { return nil }
        return CPCalculator.levels(matchingCP: cp, base: base, ivs: draft.ivs,
                                   maxLevel: tables.maxBestBuddyLevel, tables: tables)
    }

    /// A CP is typed but the stats don't give it yet (no level picked, or no level fits).
    /// Save waits, so the typed CP is never silently dropped.
    private var cpPending: Bool {
        guard let cp = cpLookup, let tables, draft.base != nil else { return false }
        return draft.cp(tables) != cp
    }

    private func applySingleCPMatch() {
        guard let tables, let matches = levelsMatchingCP(tables), matches.count == 1 else { return }
        draft.level = matches[0]
    }

    // MARK: - Sections

    private var pokemonSection: some View {
        Section("Pokémon") {
            if dataCenter.gamemaster != nil {
                NavigationLink {
                    SpeciesPicker(candidates: dataCenter.powerUpCandidates) { draft.select($0, lookup: dataCenter.lookup) }
                } label: {
                    HStack {
                        Text(draft.speciesId == nil ? "Choose Pokémon" : draft.speciesName)
                            .foregroundStyle(draft.speciesId == nil ? HierarchicalShapeStyle.secondary : .primary)
                        Spacer()
                        TypeBadges(types: draft.types)
                    }
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Loading Pokémon data…").foregroundStyle(.secondary)
                }
            }
            TextField("Nickname (optional)", text: $draft.nickname)
                .focused($keyboardFocused)
        }
    }

    private var statsSection: some View {
        Section {
            ivStepper("Attack IV", value: $draft.ivs.attack)
            ivStepper("Defense IV", value: $draft.ivs.defense)
            ivStepper("HP IV", value: $draft.ivs.stamina)
            if let tables {
                // Changing the level by hand clears the CP box, so the two can't disagree.
                Stepper(value: Binding(get: { draft.level.halfSteps }, set: { draft.level = PokemonLevel(halfSteps: $0); cpLookup = nil }),
                        in: 2...tables.maxBestBuddyLevel.halfSteps) {
                    LabeledContent("Level", value: draft.level.description)
                }
                DisclosureGroup("Find level from CP") {
                    LabeledContent("CP in game") {
                        IntField(title: "CP", value: $cpLookup, maxDigits: 5)
                            .focused($keyboardFocused)
                    }
                    levelMatches(tables)
                }
            }
        } header: {
            Text("Stats")
        } footer: {
            if let tables, let cp = draft.cp(tables), let hp = draft.hp(tables) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CP \(cp.formatted()) · HP \(hp) · IVs \(draft.ivs.percent)%")
                    if cpPending, let typed = cpLookup {
                        Text("Pick a level for CP \(typed) above, or clear the CP box, to save.")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func levelMatches(_ tables: LevelTables) -> some View {
        if let cp = cpLookup, let matches = levelsMatchingCP(tables) {
            if matches.isEmpty {
                Text("No level gives CP \(cp) with these IVs. Check the IVs, or clear the CP box.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if matches.count == 1 {
                Label("Level \(matches[0].description) applied.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("CP \(cp) fits \(matches.count) levels. Pick one:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(matches, id: \.self) { level in
                    Button {
                        draft.level = level
                        keyboardFocused = false
                    } label: {
                        HStack {
                            Text("Use level \(level.description)")
                            Spacer()
                            if draft.level == level { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        } else if draft.base == nil {
            Text("Choose a Pokémon first.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var movesSection: some View {
        Section {
            if let gm = gmPokemon, let lookup = dataCenter.lookup {
                let options = lookup.moveOptions(for: gm)
                movePicker("Fast move", selection: $draft.fastMoveId, options: options.fast, lookup: lookup, allowNone: false)
                movePicker("Charged move", selection: $draft.chargedMoveId, options: options.charged, lookup: lookup, allowNone: false)
                movePicker("Second charged move", selection: $draft.secondChargedMoveId, options: options.charged, lookup: lookup, allowNone: true)
            } else {
                Text(draft.speciesId == nil ? "Choose a Pokémon to see its moves." : "Move data is still loading.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Moves")
        } footer: {
            Text("Moves per PvPoke. ★ = Elite TM or legacy move.")
        }
    }

    private func movePicker(_ title: String, selection: Binding<String>, options: [GamemasterLookup.MoveOption],
                            lookup: GamemasterLookup, allowNone: Bool) -> some View {
        Picker(title, selection: selection) {
            Text(allowNone ? "None" : "Not set").tag("")
            ForEach(options) { option in
                Text(option.isSpecial ? "\(option.name) ★" : option.name).tag(option.id)
            }
            // Keep a saved move selectable even if the data no longer lists it.
            if !selection.wrappedValue.isEmpty && !options.contains(where: { $0.id == selection.wrappedValue }) {
                Text("\(lookup.moveName(selection.wrappedValue)) (saved)").tag(selection.wrappedValue)
            }
        }
    }

    private var flagsSection: some View {
        Section("Flags") {
            Toggle("Shiny", isOn: $draft.isShiny)
            Toggle("Shadow", isOn: $draft.isShadow)
            Toggle("Purified", isOn: $draft.isPurified)
            Toggle("Lucky", isOn: $draft.isLucky)
        }
    }

    private func ivStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: IVs.range) {
            LabeledContent(title, value: "\(value.wrappedValue)")
        }
    }

    // MARK: - Actions

    private func save() {
        guard let model = draft.apply(to: pokemon) else { return }
        if pokemon == nil { modelContext.insert(model) }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let pokemon else { return }
        modelContext.delete(pokemon)
        try? modelContext.save()
        dismiss()
    }
}
