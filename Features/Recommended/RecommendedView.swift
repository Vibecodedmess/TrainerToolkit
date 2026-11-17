import SwiftUI
import SwiftData
import GameMath
import DataSources
import Counters

/// "Recommended": which of your Pokémon to power up next, which events have something for you, and
/// which raid bosses are easiest for your collection. Worked out on the phone from your collection,
/// your goals and the feeds (`Recommender` in TrainerKit); nothing is made up.
struct RecommendedView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Query private var collection: [CollectedPokemon]
    @Query private var goals: [PowerUpGoal]

    @State private var result: Output?
    @State private var computing = false

    /// How many of each to show.
    private let shown = 5

    struct Output: Sendable {
        var powerUps: [Recommender.PowerUpPick] = []
        var bossNames: [String] = []
        var events: [Recommender.EventPick] = []
        var raids: [Recommender.RaidPick] = []
        var counterCount = 0
    }

    var body: some View {
        List {
            if let result {
                powerUpSection(result)
                eventSection(result)
                raidSection(result)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(computing ? "Working it out…" : "Waiting for data…").foregroundStyle(.secondary)
                }
            }
            Section {
                DisclosureGroup("How this is worked out") {
                    Text("""
                    Power-ups: each Pokémon in My Collection that has a fast move is taken to its next level step \
                    (40, 45 or 50) while the others stay as they are. It's suggested when that gets it into your \
                    best 6 against a current raid boss, or makes it your best. Same damage model as the raid screens.
                    Events: live events and those starting within 7 days, listed when they feature Pokémon from \
                    your goals' families (their candy helps), Pokémon you don't have yet, shinies, bonuses or \
                    research rewards, as the event feed lists them.
                    Raids: the trainers-needed estimate with your best 6, easiest first. Bosses you don't have \
                    yet and shiny ones go first among equals.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Recommended")
        .lookScreen()
        .refreshable { await dataCenter.refreshNow() }
        .task(id: inputKey) { await compute() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func powerUpSection(_ result: Output) -> some View {
        Section {
            if result.bossNames.isEmpty {
                Text("No raid bosses loaded yet, so there's nothing to compare against.").foregroundStyle(.secondary)
            } else if result.counterCount <= 6 {
                Text("Add at least 7 Pokémon with a fast move to My Collection. With 6 or fewer, they're all already in your best 6.")
                    .foregroundStyle(.secondary)
            } else if result.powerUps.isEmpty {
                Text("No single power-up step changes your best 6 against the current raid bosses.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.powerUps.prefix(shown)) { pick in
                    powerUpRow(pick, bossNames: result.bossNames)
                }
            }
        } header: {
            Text("Power up next")
        } footer: {
            Text("Against the current raid bosses, compared with the rest of My Collection.")
        }
    }

    @ViewBuilder
    private func powerUpRow(_ pick: Recommender.PowerUpPick, bossNames: [String]) -> some View {
        let pokemon = collectedPokemon(for: pick.candidate)
        let row = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(pick.candidate.name).font(.headline)
                if let pokemon {
                    FlagIcons(isShiny: pokemon.isShiny, isShadow: pokemon.isShadow, isPurified: pokemon.isPurified,
                              isLucky: pokemon.isLucky)
                }
                Spacer()
                Text("L\(pick.candidate.combatant.level.description) → L\(pick.target.description)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            if !pick.becomesBest.isEmpty {
                reason("crown", .orange, "Becomes your best against " + names(pick.becomesBest, bossNames))
            }
            let joinsOnly = pick.joinsTeam.filter { !pick.becomesBest.contains($0) }
            if !joinsOnly.isEmpty {
                reason("person.3", .blue, "Joins your best 6 against " + names(joinsOnly, bossNames))
            }
            if let pokemon, let cost = cost(pokemon, to: pick.target) {
                Text(cost).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        if let pokemon {
            NavigationLink { PowerUpValueView(pokemon: pokemon) } label: { row }
        } else {
            row
        }
    }

    @ViewBuilder
    private func eventSection(_ result: Output) -> some View {
        Section {
            if result.events.isEmpty {
                Text(dataCenter.events.isEmpty ? "Events haven't loaded yet."
                     : "Nothing in the next 7 days stands out for you.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.events.prefix(shown)) { pick in
                    NavigationLink { EventDetailView(event: pick.event) } label: { eventRow(pick) }
                }
            }
        } header: {
            Text("Events to join")
        } footer: {
            Text("Live now or starting within 7 days. Bonuses and rewards as the event feed lists them.")
        }
    }

    private func eventRow(_ pick: Recommender.EventPick) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pick.event.event.name).font(.headline).lineLimit(2)
            Group {
                if pick.event.status == .live, let end = pick.event.end {
                    Text("Live · ends \(end, format: .relative(presentation: .named))").foregroundStyle(.green)
                } else if let start = pick.event.start {
                    Text("Starts \(start, format: .relative(presentation: .named))").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            if !pick.forGoals.isEmpty {
                reason("target", .green, "Candy for your goals: " + list(pick.forGoals))
            }
            if !pick.new.isEmpty {
                reason("plus.circle", .blue, "New for your collection: " + list(pick.new))
            }
            if !pick.shinies.isEmpty {
                reason("sparkles", .yellow, "Can be shiny: " + list(pick.shinies))
            }
            if !pick.bonuses.isEmpty {
                reason("gift", .pink, "Bonuses: " + list(pick.bonuses))
            }
            if !pick.rewards.isEmpty {
                reason("scroll", .purple, "Research rewards: " + list(pick.rewards))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func raidSection(_ result: Output) -> some View {
        Section {
            if result.raids.isEmpty {
                Text("No raid bosses loaded yet.").foregroundStyle(.secondary)
            } else {
                ForEach(result.raids.prefix(6)) { pick in
                    NavigationLink { RaidBossDetailView(boss: pick.boss) } label: { raidRow(pick, hasTeam: result.counterCount > 0) }
                }
            }
        } header: {
            Text("Raids to do")
        } footer: {
            Text("Easiest for My Collection first: best-case trainers needed if everyone brings your best 6. Tap a boss for details and weather.")
        }
    }

    private func raidRow(_ pick: Recommender.RaidPick, hasTeam: Bool) -> some View {
        HStack(spacing: 10) {
            TypeStrip(types: pick.pokemon.realTypes)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pick.boss.name).font(.headline)
                    if pick.canBeShiny {
                        Image(systemName: "sparkles").foregroundStyle(.yellow).accessibilityLabel("Can be shiny")
                    }
                    Spacer()
                    Text(pick.boss.tier).font(.caption).foregroundStyle(.secondary)
                }
                if let trainers = pick.trainers {
                    reason("person.3", .blue, trainers == 1 ? "You could do it alone (best case)"
                                                            : "About \(trainers) trainers with your best 6")
                } else if let note = pick.notEstimated {
                    reason("info.circle", .secondary, note.isEmpty ? "This raid type isn't estimated." : note)
                } else if !hasTeam {
                    reason("info.circle", .secondary, "Add Pokémon with moves to My Collection for an estimate.")
                }
                if !pick.topCounters.isEmpty {
                    Text("Your best: " + pick.topCounters.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if pick.isNew {
                    reason("plus.circle", .green, "You don't have this one yet")
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Pieces

    private func reason(_ systemImage: String, _ color: Color, _ text: String) -> some View {
        Label {
            Text(text).font(.caption)
        } icon: {
            Image(systemName: systemImage).font(.caption).foregroundStyle(color)
        }
    }

    private func names(_ indexes: [Int], _ bossNames: [String]) -> String {
        list(indexes.compactMap { bossNames.indices.contains($0) ? bossNames[$0] : nil })
    }

    /// "A, B and 3 more".
    private func list(_ items: [String], max: Int = 3) -> String {
        let head = items.prefix(max).joined(separator: ", ")
        return items.count > max ? head + " and \(items.count - max) more" : head
    }

    private func cost(_ p: CollectedPokemon, to target: PokemonLevel) -> String? {
        guard let tables = PlannerMath.tables else { return nil }
        let c = PowerUpCalculator.cost(from: p.level, to: target,
                                       modifiers: CostModifiers(isShadow: p.isShadow, isPurified: p.isPurified, isLucky: p.isLucky),
                                       tables: tables)
        var parts = ["\(c.stardust.formatted()) stardust", "\(c.candy) candy"]
        if c.xlCandy > 0 { parts.append("\(c.xlCandy) XL candy") }
        return parts.joined(separator: " · ")
    }

    /// The collection entry behind a counter (ids are "mine:<index>:<species>", see `CounterPools.mine`).
    private func collectedPokemon(for candidate: CounterCandidate) -> CollectedPokemon? {
        let parts = candidate.id.split(separator: ":")
        guard parts.count >= 2, let index = Int(parts[1]), collection.indices.contains(index),
              collection[index].speciesId == candidate.speciesId else { return nil }
        return collection[index]
    }

    // MARK: - Working it out

    private struct InputKey: Hashable {
        let collection: Int
        let goals: Int
        let raids: Int
        let events: Int
        let hasLookup: Bool
    }

    private var inputKey: InputKey {
        InputKey(collection: collection.count, goals: goals.count, raids: dataCenter.raids.count,
                 events: dataCenter.events.count, hasLookup: dataCenter.lookup != nil)
    }

    private func compute() async {
        guard let lookup = dataCenter.lookup, let battle = BattleData.battle, let levels = PlannerMath.tables,
              let table = RaidData.table else { return }
        computing = true
        let team = CounterPools.mine(collection, lookup: lookup)
        let owned = Set(collection.map(\.speciesId))
        let goalIds = Set(goals.map(\.speciesId))
        let bosses = dataCenter.raids
        let events = EventCalendar.resolve(dataCenter.events, now: .now)
        let resolved: [(name: String, defender: Combatant)] = bosses.compactMap { boss in
            guard let p = CounterRanker.resolve(boss.name, lookup: lookup) else { return nil }
            return (boss.name, CounterRanker.defender(p, isShadow: boss.tier.lowercased().contains("shadow")))
        }
        let output = await Task.detached(priority: .userInitiated) { () -> Output in
            var out = Output()
            out.counterCount = team.count
            out.bossNames = resolved.map(\.name)
            out.powerUps = Recommender.powerUps(team, defenders: resolved.map(\.defender), weather: nil,
                                                tables: levels, battle: battle)
            out.events = Recommender.events(events, now: .now, goalSpeciesIds: goalIds, ownedSpeciesIds: owned,
                                            lookup: lookup)
            out.raids = Recommender.raids(bosses, team: team, ownedSpeciesIds: owned, table: table, weather: nil,
                                          lookup: lookup, levels: levels, battle: battle)
            return out
        }.value
        guard !Task.isCancelled else { return }
        result = output
        computing = false
    }
}

#Preview {
    NavigationStack { RecommendedView() }
        .environment(DataCenter())
}
