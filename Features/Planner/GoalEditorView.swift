import SwiftUI
import SwiftData
import GameMath
import DataSources

/// Create or edit one power-up goal. All numbers update live.
struct GoalEditorView: View {
    /// nil = new goal (shown in a sheet with Cancel).
    let goal: PowerUpGoal?

    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GoalDraft
    @State private var cpLookup: Int?
    @FocusState private var keyboardFocused: Bool

    init(goal: PowerUpGoal?) {
        self.goal = goal
        _draft = State(initialValue: goal.map { GoalDraft(goal: $0, types: []) } ?? GoalDraft())
    }

    var body: some View {
        if let tables = PlannerMath.tables {
            form(tables)
        } else {
            ContentUnavailableView("Level tables missing", systemImage: "exclamationmark.triangle",
                                   description: Text("The built-in cost tables could not be read."))
        }
    }

    private func form(_ tables: LevelTables) -> some View {
        Form {
            pokemonSection
            statsSection(tables)
            goalSection(tables)
            resultSection(tables)
            timingSection(tables)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(goal == nil ? "New goal" : draft.speciesName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if goal == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!draft.isComplete)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardFocused = false }
            }
        }
        .onAppear {
            if draft.types.isEmpty, let id = draft.speciesId, let gm = dataCenter.gamemaster {
                draft.types = gm.types(forSpecies: id)
            }
        }
        .onChange(of: draft.isBestBuddy) { _, _ in draft.clampLevels(tables) }
        .onChange(of: draft.isShadow) { _, on in if on { draft.isPurified = false; draft.isLucky = false } }
        .onChange(of: draft.isPurified) { _, on in if on { draft.isShadow = false } }
        .onChange(of: draft.isLucky) { _, on in if on { draft.isShadow = false } }
    }

    // MARK: - Sections

    private var pokemonSection: some View {
        Section("Pokémon") {
            if dataCenter.gamemaster != nil {
                NavigationLink {
                    SpeciesPicker(candidates: dataCenter.powerUpCandidates) { draft.select($0) }
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
                    Text("Loading Pokémon data…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statsSection(_ tables: LevelTables) -> some View {
        Section {
            ivStepper("Attack IV", value: $draft.ivs.attack)
            ivStepper("Defense IV", value: $draft.ivs.defense)
            ivStepper("HP IV", value: $draft.ivs.stamina)
            Stepper(value: halfSteps(\.current), in: 2...draft.maxLevel(tables).halfSteps) {
                LabeledContent("Current level", value: draft.current.description)
            }
            DisclosureGroup("Find level from CP") {
                LabeledContent("CP in game") {
                    IntField(title: "CP", value: $cpLookup, maxDigits: 5)
                        .focused($keyboardFocused)
                }
                levelMatches(tables)
            }
        } header: {
            Text("Your Pokémon")
        } footer: {
            if let cp = draft.cp(at: draft.current, tables) {
                Text("CP at level \(draft.current.description): \(cp.formatted()) (IVs \(draft.ivs.percent)%)")
            }
        }
    }

    @ViewBuilder
    private func levelMatches(_ tables: LevelTables) -> some View {
        if let cp = cpLookup, let base = draft.base {
            let matches = CPCalculator.levels(matchingCP: cp, base: base, ivs: draft.ivs,
                                              maxLevel: tables.maxBestBuddyLevel, tables: tables)
            if matches.isEmpty {
                Text("No level gives CP \(cp) with these IVs. Check the IVs and the Pokémon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches, id: \.self) { level in
                    Button("Use level \(level.description)") {
                        draft.current = level
                        keyboardFocused = false
                    }
                }
            }
        } else if draft.base == nil {
            Text("Choose a Pokémon first.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func goalSection(_ tables: LevelTables) -> some View {
        Section {
            Stepper(value: halfSteps(\.target), in: 2...draft.maxLevel(tables).halfSteps) {
                LabeledContent("Target level", value: draft.target.description)
            }
            HStack {
                quickTarget(40)
                quickTarget(tables.maxNormalUpgradeLevel)
                if draft.isBestBuddy {
                    quickTarget(tables.maxNormalUpgradeLevel + tables.bestBuddyExtraLevels)
                }
            }
            Toggle("Shadow", isOn: $draft.isShadow)
            Toggle("Purified", isOn: $draft.isPurified)
            Toggle("Lucky", isOn: $draft.isLucky)
            Toggle("Best Buddy", isOn: $draft.isBestBuddy)
        } header: {
            Text("Goal")
        } footer: {
            Text(modifierNote(tables))
        }
    }

    private func modifierNote(_ t: LevelTables) -> String {
        let shadow = "Shadow: stardust ×\(format(t.shadowStardustMultiplier)), candy ×\(format(t.shadowCandyMultiplier))."
        let purified = "Purified: stardust ×\(format(t.purifiedStardustMultiplier)), candy ×\(format(t.purifiedCandyMultiplier))."
        let lucky = "Lucky: stardust ×\(format(t.luckyStardustDiscount))."
        let buddy = "Best Buddy: +\(t.bestBuddyExtraLevels) level for CP, at no cost."
        return [shadow, purified, lucky, buddy].joined(separator: " ")
    }

    private func quickTarget(_ level: Int) -> some View {
        Button("Level \(level)") { draft.target = PokemonLevel(Double(level)) }
            .buttonStyle(.bordered)
            .disabled(draft.target == PokemonLevel(Double(level)))
    }

    private func resultSection(_ tables: LevelTables) -> some View {
        let cost = draft.cost(tables)
        return Section {
            if draft.target <= draft.current {
                Text("Set a target level above the current level.")
                    .foregroundStyle(.secondary)
            }
            if let now = draft.cp(at: draft.current, tables), let then = draft.cp(at: draft.target, tables) {
                LabeledContent("CP", value: "\(now.formatted()) → \(then.formatted())")
            }
            LabeledContent("Stardust", value: cost.stardust.formatted())
            LabeledContent("Candy", value: cost.candy.formatted())
            LabeledContent("XL Candy", value: cost.xlCandy.formatted())
            LabeledContent("Power-ups", value: cost.powerUps.formatted())
            if draft.target > tables.maxUpgradeLevel {
                Text("Levels above \(tables.maxNormalUpgradeLevel) come from the Best Buddy boost and cost nothing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Needed")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Costs from the game master (PokeMiners, commit \(String(tables.source.commit.prefix(7))), extracted \(tables.source.extracted)).")
                if draft.isShadow || draft.isPurified || draft.isLucky {
                    Text("TODO: verify. Fractional shadow/purified/lucky costs are rounded up per power-up; the game master doesn't say how the game rounds.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func timingSection(_ tables: LevelTables) -> some View {
        let cost = draft.cost(tables)
        let progress = GoalEstimator.progress(cost: cost, have: draft.owned)
        let days = GoalEstimator.daysNeeded(cost: cost, have: draft.owned, income: draft.dailyIncome)
        return Section {
            LabeledContent("Candy you have") {
                ZeroIntField(title: "0", value: $draft.candyOwned).focused($keyboardFocused)
            }
            LabeledContent("XL Candy you have") {
                ZeroIntField(title: "0", value: $draft.xlCandyOwned).focused($keyboardFocused)
            }
            Picker("Income", selection: $draft.incomeIsPerWeek) {
                Text("Per day").tag(false)
                Text("Per week").tag(true)
            }
            .pickerStyle(.segmented)
            LabeledContent("Candy income") {
                DecimalField(title: "0", value: $draft.candyIncome).focused($keyboardFocused)
            }
            LabeledContent("XL Candy income") {
                DecimalField(title: "0", value: $draft.xlCandyIncome).focused($keyboardFocused)
            }
            ProgressView(value: progress) {
                Text("Candy + XL Candy collected")
            } currentValueLabel: {
                Text("\(Int((progress * 100).rounded(.down)))%")
            }
            etaRow(days: days)
        } header: {
            Text("Progress & timing")
        } footer: {
            Text("Estimate based on your own income numbers. Stardust is not included.")
        }
    }

    @ViewBuilder
    private func etaRow(days: Int?) -> some View {
        if let days {
            if days == 0 {
                Label("You have enough Candy and XL Candy", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
                LabeledContent("Ready around", value: "\(date.formatted(date: .abbreviated, time: .omitted)) (\(days) days)")
            }
        } else {
            Text("Add Candy and XL Candy income to see when you'll be ready.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func ivStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: IVs.range) {
            LabeledContent(title, value: "\(value.wrappedValue)")
        }
    }

    private func halfSteps(_ keyPath: WritableKeyPath<GoalDraft, PokemonLevel>) -> Binding<Int> {
        Binding(
            get: { draft[keyPath: keyPath].halfSteps },
            set: { draft[keyPath: keyPath] = PokemonLevel(halfSteps: $0) }
        )
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func save() {
        guard let model = draft.apply(to: goal) else { return }
        if goal == nil { modelContext.insert(model) }
        try? modelContext.save()
        dismiss()
    }
}
