import SwiftUI
import SwiftData
import GameMath
import DataSources
import Counters

/// One Rocket lineup: the possible Pokémon per slot, with counters per slot and per Pokémon.
struct RocketLineupView: View {
    let lineup: SDRocketLineup

    @Environment(DataCenter.self) private var dataCenter
    @Query(sort: \CollectedPokemon.createdAt, order: .reverse) private var collection: [CollectedPokemon]
    @AppStorage(CounterSettingsKeys.pool) private var pool: CounterPool = .generic
    @AppStorage(CounterSettingsKeys.level) private var level: Double = 40
    @AppStorage(CounterSettingsKeys.shadow) private var includeShadow = true
    @AppStorage(CounterSettingsKeys.mega) private var includeMega = false
    @AppStorage(CounterSettingsKeys.special) private var includeSpecial = true
    @State private var weather = ""
    @State private var slots: [SlotResult] = []
    @State private var computing = false

    struct Member: Hashable {
        let name: String
        let types: [String]
        let isEncounter: Bool
        let canBeShiny: Bool
        /// Nil when the name couldn't be matched to the Pokémon data.
        let defender: Combatant?
    }

    struct SlotResult: Hashable {
        let index: Int
        let best: [ScoredCandidate]
        /// Member name -> top counters against it.
        let perMember: [String: [CounterResult]]
    }

    struct ScoredCandidate: Hashable, Identifiable {
        let candidate: CounterCandidate
        let score: Double
        var id: String { candidate.id }
    }

    private var memberSlots: [[Member]] {
        [lineup.firstPokemon, lineup.secondPokemon, lineup.thirdPokemon].map { slot in
            (slot ?? []).map(member)
        }
    }

    private func member(_ m: SDRocketLineup.Member) -> Member {
        let gm = dataCenter.lookup.flatMap { CounterRanker.resolve(m.name, lookup: $0) }
        let types = gm?.realTypes ?? (m.types ?? []).map { $0.lowercased() }
        // Rocket Pokémon are shadow Pokémon; `defender(isShadow:)` applies the shadow defence multiplier.
        return Member(name: m.name, types: types, isEncounter: m.isEncounter == true, canBeShiny: m.canBeShiny == true,
                      defender: gm.map { CounterRanker.defender($0, isShadow: true) })
    }

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
            Section {
                if let title = lineup.title, !title.isEmpty { LabeledContent("Role", value: title) }
                if let type = lineup.type, !type.isEmpty { LabeledContent("Type") { TypeBadge(type: type) } }
                Text("Counters assume the opponent's Pokémon are shadow Pokémon. In-battle shields and charged-move timing are not modelled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let battle = BattleData.battle {
                CounterSettingsSection(pool: $pool, level: $level, includeShadow: $includeShadow, includeMega: $includeMega,
                                       includeSpecial: $includeSpecial, weather: $weather,
                                       weatherChoices: battle.weatherConditions, mineCount: mine.count)
                ForEach(Array(memberSlots.enumerated()), id: \.offset) { index, members in
                    if !members.isEmpty { slotSection(index, members, battle: battle) }
                }
            } else {
                Section { Text("Battle data couldn't be loaded.").foregroundStyle(.secondary) }
            }
            Section { CounterMethodNote() }
        }
        .navigationTitle(lineup.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: TaskKey(inputs: inputs, slots: memberSlots)) { await compute() }
    }

    private struct TaskKey: Hashable {
        let inputs: CounterInputs
        let slots: [[Member]]
    }

    private func slotSection(_ index: Int, _ members: [Member], battle: BattleTables) -> some View {
        let result = slots.first { $0.index == index }
        return Section {
            ForEach(members, id: \.name) { m in
                DisclosureGroup {
                    if m.defender == nil {
                        Text("Couldn't match \(m.name) to the Pokémon data.").font(.footnote).foregroundStyle(.secondary)
                    } else if let counters = result?.perMember[m.name], !counters.isEmpty {
                        ForEach(Array(counters.enumerated()), id: \.element.id) { i, r in
                            CounterRow(rank: i + 1, name: r.candidate.name, candidate: r.candidate, moveset: r.moveset,
                                       score: r.relativeDPS, lookup: dataCenter.lookup)
                        }
                    } else {
                        Text(computing ? "Ranking…" : "No counters found.").foregroundStyle(.secondary)
                    }
                    let weak = CounterRanker.weaknesses(of: m.types, battle: battle)
                    if !weak.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weak to").font(.caption).foregroundStyle(.secondary)
                            TypeMultiplierList(items: weak)
                        }
                    }
                } label: {
                    HStack {
                        Text(m.name)
                        if m.isEncounter {
                            Image(systemName: "circle.circle").foregroundStyle(.tint).accessibilityLabel("Can be caught after the battle")
                        }
                        if m.canBeShiny {
                            Image(systemName: "sparkles").foregroundStyle(.yellow).accessibilityLabel("Can be shiny")
                        }
                        Spacer()
                        TypeBadges(types: m.types)
                    }
                }
            }
            if let best = result?.best, !best.isEmpty, members.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good against all of these").font(.subheadline.weight(.semibold))
                    ForEach(Array(best.enumerated()), id: \.element.id) { i, s in
                        HStack {
                            Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                            Text(s.candidate.name)
                            if s.candidate.combatant.isShadow { Image(systemName: "flame.fill").foregroundStyle(.purple) }
                            if s.candidate.isMine { Image(systemName: "person.crop.circle.badge.checkmark").foregroundStyle(.tint) }
                            Spacer()
                            Text(s.score, format: .percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    Text("% = average compared with the best counter for each possible Pokémon.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Pokémon \(index + 1)" + (members.count > 1 ? " (one of \(members.count))" : ""))
        }
    }

    private func compute() async {
        guard let battle = BattleData.battle, let levels = PlannerMath.tables, let gm = dataCenter.gamemaster else {
            slots = []
            return
        }
        computing = true
        let inputs = self.inputs
        let memberSlots = self.memberSlots
        let computed = await Task.detached(priority: .userInitiated) { () -> [SlotResult] in
            let candidates = CounterPools.candidates(inputs, gamemaster: gm)
            return memberSlots.enumerated().map { index, members in
                var perMember: [String: [CounterResult]] = [:]
                for m in members {
                    guard let d = m.defender else { continue }
                    perMember[m.name] = CounterRanker.rank(candidates, against: d, weather: inputs.weather,
                                                           levels: levels, battle: battle, limit: 3)
                }
                let defenders = members.compactMap(\.defender)
                let best = defenders.count > 1
                    ? CounterRanker.rankAgainstAll(candidates, defenders: defenders, weather: inputs.weather,
                                                   levels: levels, battle: battle, limit: 3)
                        .map { ScoredCandidate(candidate: $0.candidate, score: $0.score) }
                    : []
                return SlotResult(index: index, best: best, perMember: perMember)
            }
        }.value
        guard !Task.isCancelled else { return }
        slots = computed
        computing = false
    }
}
