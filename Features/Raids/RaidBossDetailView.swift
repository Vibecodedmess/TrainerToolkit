import SwiftUI
import SwiftData
import GameMath
import DataSources
import Counters

/// One raid boss: types, weaknesses and the best counters (generic or from My Collection).
struct RaidBossDetailView: View {
    let boss: SDRaidBoss

    @Environment(DataCenter.self) private var dataCenter
    @Query(sort: \CollectedPokemon.createdAt, order: .reverse) private var collection: [CollectedPokemon]
    @AppStorage(CounterSettingsKeys.pool) private var pool: CounterPool = .generic
    @AppStorage(CounterSettingsKeys.level) private var level: Double = 40
    @AppStorage(CounterSettingsKeys.shadow) private var includeShadow = true
    @AppStorage(CounterSettingsKeys.mega) private var includeMega = false
    @AppStorage(CounterSettingsKeys.special) private var includeSpecial = true
    @State private var weather = ""
    @State private var results: [CounterResult] = []
    @State private var computing = false

    /// Party size in a raid.
    private let partySize = 6

    private var gmBoss: GMPokemon? { dataCenter.lookup.flatMap { CounterRanker.resolve(boss.name, lookup: $0) } }
    /// Types from the gamemaster when the boss is matched, else from the feed.
    private var bossTypes: [String] { gmBoss?.realTypes ?? (boss.types ?? []).map { $0.name.lowercased() } }

    private var mine: [CounterCandidate] { CounterPools.mine(collection, lookup: dataCenter.lookup) }

    private var inputs: CounterInputs {
        CounterInputs(pool: pool,
                      options: .init(level: PokemonLevel(level), includeShadow: includeShadow,
                                     includeMega: includeMega, includeSpecialMoves: includeSpecial),
                      weather: weather.isEmpty ? nil : weather,
                      mine: pool == .mine ? mine : [])
    }

    var body: some View {
        Form {
            bossSection
            if let battle = BattleData.battle {
                Section("Weak to") { TypeMultiplierList(items: CounterRanker.weaknesses(of: bossTypes, battle: battle)) }
                Section("Resists") { TypeMultiplierList(items: CounterRanker.resistances(of: bossTypes, battle: battle)) }
                CounterSettingsSection(pool: $pool, level: $level, includeShadow: $includeShadow, includeMega: $includeMega,
                                       includeSpecial: $includeSpecial, weather: $weather,
                                       weatherChoices: battle.weatherConditions,
                                       highlightedWeather: BattleData.weather(boosting: bossTypes, battle: battle),
                                       mineCount: mine.count)
                countersSections
            } else {
                Section { Text("Battle data couldn't be loaded.").foregroundStyle(.secondary) }
            }
            Section { CounterMethodNote() }
        }
        .navigationTitle(boss.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: TaskKey(inputs: inputs, boss: gmBoss?.speciesId)) { await compute() }
    }

    private struct TaskKey: Hashable {
        let inputs: CounterInputs
        let boss: String?
    }

    private var bossSection: some View {
        Section {
            LabeledContent("Tier", value: boss.tier)
            LabeledContent("Type") { TypeBadges(types: bossTypes) }
            if let cp = boss.combatPower?.normal {
                LabeledContent("CP", value: "\(cp.min)–\(cp.max)")
            }
            if let cp = boss.combatPower?.boosted {
                LabeledContent("CP, weather boosted", value: "\(cp.min)–\(cp.max)")
            }
            if boss.canBeShiny == true {
                Label("Can be shiny", systemImage: "sparkles")
            }
            if gmBoss == nil {
                Text("This boss couldn't be matched to the Pokémon data, so counters use its types from the raid feed only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var countersSections: some View {
        if computing && results.isEmpty {
            Section { HStack { ProgressView(); Text("Ranking counters…").foregroundStyle(.secondary) } }
        } else if results.isEmpty {
            Section {
                Text(pool == .mine ? "None of your Pokémon have moves with battle data yet." : "No counters found.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(Array(results.prefix(partySize).enumerated()), id: \.element.id) { index, r in
                    row(index + 1, r)
                }
            } header: {
                Text("Suggested party of \(partySize)")
            } footer: {
                Text("% = estimated damage per second compared with the best counter.")
            }
            if results.count > partySize {
                Section("More counters") {
                    ForEach(Array(results.dropFirst(partySize).prefix(14).enumerated()), id: \.element.id) { index, r in
                        row(index + 1 + partySize, r)
                    }
                }
            }
        }
    }

    private func row(_ rank: Int, _ r: CounterResult) -> some View {
        CounterRow(rank: rank, name: r.candidate.name, candidate: r.candidate, moveset: r.moveset,
                   score: r.relativeDPS, lookup: dataCenter.lookup)
    }

    private func compute() async {
        guard let battle = BattleData.battle, let levels = PlannerMath.tables, let gm = dataCenter.gamemaster else {
            results = []
            return
        }
        computing = true
        let inputs = self.inputs
        let defender: Combatant
        if let gmBoss {
            defender = CounterRanker.defender(gmBoss)
        } else {
            // Unmatched boss: only its feed types are known. Neutral stand-in stats (the ranking
            // depends on the types; defence only scales every counter's damage by the same factor).
            defender = Combatant(base: BaseStats(attack: 200, defense: 200, stamina: 200),
                                 ivs: CounterRanker.standInDefenderIVs, level: CounterRanker.standInDefenderLevel,
                                 types: bossTypes)
        }
        let limit = partySize + 14
        let ranked = await Task.detached(priority: .userInitiated) {
            let candidates = CounterPools.candidates(inputs, gamemaster: gm)
            return CounterRanker.rank(candidates, against: defender, weather: inputs.weather,
                                      levels: levels, battle: battle, limit: limit)
        }.value
        guard !Task.isCancelled else { return }
        results = ranked
        computing = false
    }
}
