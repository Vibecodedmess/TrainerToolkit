import SwiftUI
import SwiftData
import GameMath
import DataSources
import Counters

extension GoalDraft {
    /// A power-up goal for a Pokémon in My Collection, from its current level to `target`.
    init(collected p: CollectedPokemon, types: [String], target: PokemonLevel) {
        self.init()
        speciesId = p.speciesId
        speciesName = p.speciesName
        self.types = types
        base = p.baseStats
        ivs = p.ivs
        current = p.level
        self.target = max(target, p.level)
        isShadow = p.isShadow
        isPurified = p.isPurified
        isLucky = p.isLucky
    }
}

/// For one Pokémon in My Collection: how its raid strength changes with power-ups (and evolving),
/// compared with your other counters, and what each step costs.
struct PowerUpValueView: View {
    let pokemon: CollectedPokemon

    @Environment(DataCenter.self) private var dataCenter
    @Query private var collection: [CollectedPokemon]
    @State private var bossIndex = 0
    @State private var weather = ""
    /// "" = as it is; otherwise the species id of an evolution.
    @State private var form = ""
    @State private var points: [PowerUpValue.Point] = []
    @State private var computing = false
    @State private var usedSpeciesMoves = false

    private var tables: LevelTables? { PlannerMath.tables }

    /// Raid bosses that could be matched to the Pokémon data.
    private var bosses: [(boss: SDRaidBoss, pokemon: GMPokemon)] {
        guard let lookup = dataCenter.lookup else { return [] }
        let order = RaidsView.tiers(dataCenter.raids)
        return order.flatMap { tier in
            dataCenter.raids.filter { $0.tier == tier }.compactMap { b -> (boss: SDRaidBoss, pokemon: GMPokemon)? in
                guard let p = CounterRanker.resolve(b.name, lookup: lookup) else { return nil }
                return (boss: b, pokemon: p)
            }
        }
    }

    /// Evolutions this Pokémon can make, as PvPoke entries (mega/unknown forms left out).
    private var evolutions: [GMPokemon] {
        guard let lookup = dataCenter.lookup, let tables = EvolutionData.tables else { return [] }
        var seen: Set<String> = []
        return tables.branches(forSpecies: pokemon.speciesId).compactMap { b in
            guard let p = lookup.pokemon(id: b.targetKey) ?? lookup.pokemon(id: b.evolution.lowercased()),
                  seen.insert(p.speciesId).inserted else { return nil }
            return p
        }
    }

    var body: some View {
        Form {
            planSection
            if let battle = BattleData.battle, !bosses.isEmpty {
                settingsSection(battle)
                levelsSection
            } else {
                Section {
                    Text("No current raid bosses to compare against. Pull down on the Raids tab to refresh.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                DisclosureGroup("How this is calculated") {
                    Text("""
                    Each row is this Pokémon at that level (same IVs), with its best moveset against the chosen \
                    raid boss, compared with the other Pokémon in My Collection at their current levels. \
                    The rank and % use the same damage model as the Raids tab: the boss is modelled at a \
                    stand-in level, so % is relative to your best counter, not exact DPS. \
                    Evolved forms use the evolution's regular moves (evolving gives random moves). \
                    Costs are from the current level and include shadow, purified and lucky pricing.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Power up \(pokemon.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: TaskKey(boss: bossIndex, weather: weather, form: form, count: collection.count)) { await compute() }
    }

    private struct TaskKey: Hashable {
        let boss: Int
        let weather: String
        let form: String
        let count: Int
    }

    // MARK: - Sections

    private var planSection: some View {
        Section {
            if let tables = PlannerMath.tables {
                ForEach(planTargets(tables), id: \.self) { target in
                    NavigationLink {
                        GoalEditorView(prefilled: GoalDraft(collected: pokemon, types: types, target: target))
                    } label: {
                        Label("Plan to level \(target.description)", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
        } header: {
            Text("Planner")
        } footer: {
            Text("Starts a Planner goal with this Pokémon's level, IVs and flags filled in. Add your candy there to see how long it takes.")
        }
    }

    private func settingsSection(_ battle: BattleTables) -> some View {
        Section {
            Picker("Raid boss", selection: $bossIndex) {
                ForEach(Array(bosses.enumerated()), id: \.offset) { index, item in
                    Text("\(item.boss.name) (\(item.boss.tier))").tag(index)
                }
            }
            Picker("Weather", selection: $weather) {
                Text("No weather boost").tag("")
                ForEach(battle.weatherConditions, id: \.self) { Text(BattleData.weatherName($0)).tag($0) }
            }
            if !evolutions.isEmpty {
                Picker("Compare as", selection: $form) {
                    Text("\(pokemon.speciesName) (now)").tag("")
                    ForEach(evolutions) { Text("Evolved: \($0.speciesName)").tag($0.speciesId) }
                }
            }
        } header: {
            Text("Compare against")
        }
    }

    @ViewBuilder
    private var levelsSection: some View {
        Section {
            if computing && points.isEmpty {
                HStack { ProgressView(); Text("Calculating…").foregroundStyle(.secondary) }
            } else if points.isEmpty {
                Text("This Pokémon has no moves with battle data.").foregroundStyle(.secondary)
            } else if let tables = PlannerMath.tables {
                ForEach(points) { point in
                    levelRow(point, tables: tables)
                }
            }
        } header: {
            Text(form.isEmpty ? "Raid strength by level" : "Raid strength after evolving")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rank among the Pokémon in My Collection that have a fast move. % = compared with your best counter for this boss.")
                if usedSpeciesMoves {
                    Text("This Pokémon has no fast move saved, so its best regular moves are used.")
                }
            }
        }
    }

    private func levelRow(_ point: PowerUpValue.Point, tables: LevelTables) -> some View {
        let isNow = point.level == pokemon.level
        let cost = PowerUpCalculator.cost(from: pokemon.level, to: point.level,
                                          modifiers: CostModifiers(isShadow: pokemon.isShadow, isPurified: pokemon.isPurified,
                                                                   isLucky: pokemon.isLucky), tables: tables)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(isNow ? "Now · level \(point.level.description)" : "Level \(point.level.description)")
                    .font(.headline)
                if let cp = cp(at: point.level, tables: tables) {
                    Text("CP \(cp)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("#\(point.rank) of \(point.ofCount)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: min(max(point.relativeToBest, 0), 1))
                .accessibilityLabel("\(Int((point.relativeToBest * 100).rounded())) percent of your best counter")
            HStack {
                Text(point.relativeToBest, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                Spacer()
                if !isNow {
                    Text(costText(cost))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var types: [String] { dataCenter.lookup?.pokemon(id: pokemon.speciesId)?.realTypes ?? [] }

    /// Targets for "Plan to level": the comparison levels above the current one.
    private func planTargets(_ tables: LevelTables) -> [PokemonLevel] {
        Array(PowerUpValue.comparisonLevels(from: pokemon.level, maxLevel: tables.maxUpgradeLevel).dropFirst())
    }

    private func cp(at level: PokemonLevel, tables: LevelTables) -> Int? {
        let base: BaseStats
        if !form.isEmpty, let target = dataCenter.lookup?.pokemon(id: form) {
            base = BaseStats(attack: target.baseStats.atk, defense: target.baseStats.def, stamina: target.baseStats.hp)
        } else {
            base = pokemon.baseStats
        }
        return CPCalculator.cp(base: base, ivs: pokemon.ivs, level: level, tables: tables)
    }

    private func costText(_ cost: PowerUpCost) -> String {
        var parts = ["\(cost.stardust.formatted()) stardust", "\(cost.candy) candy"]
        if cost.xlCandy > 0 { parts.append("\(cost.xlCandy) XL") }
        return parts.joined(separator: " · ")
    }

    /// This Pokémon as a counter. Without a saved fast move, its species' regular moves are used.
    private func subjectCandidate() -> (CounterCandidate, Bool)? {
        guard let lookup = dataCenter.lookup, let gm = lookup.pokemon(id: pokemon.speciesId) else { return nil }
        let combatant = Combatant(base: pokemon.baseStats, ivs: pokemon.ivs, level: pokemon.level,
                                  types: gm.realTypes, isShadow: pokemon.isShadow)
        if !pokemon.fastMoveId.isEmpty {
            return (CounterCandidate(id: "subject", speciesId: pokemon.speciesId, name: pokemon.displayName, combatant: combatant,
                                     fastMoveIds: [pokemon.fastMoveId], chargedMoveIds: pokemon.chargedMoveIds, isMine: true), false)
        }
        let special = Set(gm.eliteMoves + gm.legacyMoves)
        return (CounterCandidate(id: "subject", speciesId: pokemon.speciesId, name: pokemon.displayName, combatant: combatant,
                                 fastMoveIds: gm.fastMoves.filter { !special.contains($0) },
                                 chargedMoveIds: gm.chargedMoves.filter { !special.contains($0) }, isMine: true), true)
    }

    private func compute() async {
        guard let battle = BattleData.battle, let tables = PlannerMath.tables, bosses.indices.contains(bossIndex),
              let subjectInfo = subjectCandidate() else {
            points = []
            return
        }
        let subject = subjectInfo.0
        computing = true
        usedSpeciesMoves = subjectInfo.1 && form.isEmpty
        var candidate = subject
        if !form.isEmpty, let target = dataCenter.lookup?.pokemon(id: form),
           let evolved = PowerUpValue.evolvedCandidate(from: subject, into: target) {
            candidate = evolved
        }
        let others = CounterPools.mine(collection.filter { $0.persistentModelID != pokemon.persistentModelID },
                                       lookup: dataCenter.lookup)
        let defender = CounterRanker.defender(bosses[bossIndex].pokemon)
        let levels = PowerUpValue.comparisonLevels(from: pokemon.level, maxLevel: tables.maxUpgradeLevel)
        let weatherId: String? = weather.isEmpty ? nil : weather
        let finalCandidate = candidate
        let result = await Task.detached(priority: .userInitiated) {
            PowerUpValue.evaluate(finalCandidate, at: levels, others: others, against: defender, weather: weatherId,
                                  tables: tables, battle: battle)
        }.value
        guard !Task.isCancelled else { return }
        points = result
        computing = false
    }
}
