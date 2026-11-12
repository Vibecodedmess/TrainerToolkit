import SwiftUI
import SwiftData
import GameMath
import DataSources
import Counters

/// PvE battle tables bundled with the app (PokeMiners extract).
enum BattleData {
    static let battle: BattleTables? = try? BattleTables.bundled()

    /// Game master weather id ("partly_cloudy") as text ("Partly cloudy").
    static func weatherName(_ id: String) -> String {
        let text = id.replacingOccurrences(of: "_", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Weather conditions (game master ids) that boost any of these types.
    static func weather(boosting types: [String], battle: BattleTables) -> [String] {
        battle.weatherConditions.filter { w in types.contains { battle.isBoosted($0, in: w) } }
    }
}

/// Raid tier numbers (community table, unverified) for the trainers-needed estimate.
enum RaidData {
    static let table: RaidEstimate.Table? = try? RaidEstimate.Table.bundled()
}

/// Where counters come from.
enum CounterPool: String, CaseIterable, Identifiable {
    case generic = "All Pokémon"
    case mine = "My collection"
    var id: String { rawValue }
}

/// Counter settings shared by the Raid and Rocket screens. Remembered between launches.
struct CounterSettingsKeys {
    static let pool = "counters.pool"
    static let level = "counters.level"
    static let shadow = "counters.includeShadow"
    static let mega = "counters.includeMega"
    static let special = "counters.includeSpecialMoves"
    static let levelChoices: [Double] = [20, 25, 30, 35, 40, 45, 50]
}

/// Everything a ranking depends on, so `.task(id:)` reruns only when something changes.
struct CounterInputs: Hashable {
    var pool: CounterPool
    var options: CounterRanker.GenericOptions
    var weather: String?
    var mine: [CounterCandidate]
}

enum CounterPools {
    /// My Collection entries as counter candidates (only their own moves).
    static func mine(_ collection: [CollectedPokemon], lookup: GamemasterLookup?) -> [CounterCandidate] {
        collection.enumerated().compactMap { index, p in
            guard !p.fastMoveId.isEmpty else { return nil }
            let types = lookup?.pokemon(id: p.speciesId)?.realTypes ?? []
            guard !types.isEmpty else { return nil }
            return CounterCandidate(
                id: "mine:\(index):\(p.speciesId)",
                speciesId: p.speciesId, name: p.displayName,
                combatant: Combatant(base: p.baseStats, ivs: p.ivs, level: p.level, types: types, isShadow: p.isShadow),
                fastMoveIds: [p.fastMoveId], chargedMoveIds: p.chargedMoveIds, isMine: true)
        }
    }

    static func candidates(_ inputs: CounterInputs, gamemaster: Gamemaster) -> [CounterCandidate] {
        switch inputs.pool {
        case .generic: return CounterRanker.genericCandidates(gamemaster, options: inputs.options)
        case .mine: return inputs.mine
        }
    }
}

/// Pool, level and filter controls (a Form section).
struct CounterSettingsSection: View {
    @Binding var pool: CounterPool
    @Binding var level: Double
    @Binding var includeShadow: Bool
    @Binding var includeMega: Bool
    @Binding var includeSpecial: Bool
    @Binding var weather: String
    let weatherChoices: [String]
    /// Weather conditions that boost this boss (from the raid feed); shown with a marker.
    var highlightedWeather: [String] = []
    let mineCount: Int

    var body: some View {
        Section {
            Picker("Counters from", selection: $pool) {
                ForEach(CounterPool.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Weather", selection: $weather) {
                Text("No weather boost").tag("")
                ForEach(weatherChoices, id: \.self) { w in
                    let name = BattleData.weatherName(w)
                    Text(highlightedWeather.contains(w) ? "\(name) (boosts the boss too)" : name).tag(w)
                }
            }
            if pool == .generic {
                Picker("Attacker level", selection: $level) {
                    ForEach(CounterSettingsKeys.levelChoices, id: \.self) { Text(PokemonLevel($0).description).tag($0) }
                }
                Toggle("Include shadow Pokémon", isOn: $includeShadow)
                Toggle("Include mega Pokémon", isOn: $includeMega)
                Toggle("Include Elite TM / legacy moves", isOn: $includeSpecial)
            }
        } header: {
            Text("Counters")
        } footer: {
            if pool == .generic {
                Text("Every released Pokémon at the chosen level with 15/15/15 IVs and its best moveset.")
            } else if mineCount == 0 {
                Text("No usable Pokémon in My Collection yet. Entries need a species and a fast move.")
            } else {
                Text("\(mineCount) Pokémon from My Collection, with the moves they know.")
            }
        }
    }
}

/// One ranked counter.
struct CounterRow: View {
    let rank: Int
    let name: String
    let candidate: CounterCandidate
    let moveset: DamageCalculator.MovesetResult
    /// 0…1 relative to the best counter in the list.
    let score: Double
    let lookup: GamemasterLookup?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(name).font(.headline).lineLimit(1)
                    if candidate.combatant.isShadow {
                        Image(systemName: "flame.fill").foregroundStyle(.purple).accessibilityLabel("Shadow")
                    }
                    if candidate.isMine {
                        Image(systemName: "person.crop.circle.badge.checkmark").foregroundStyle(.tint)
                            .accessibilityLabel("From my collection")
                    }
                    Spacer()
                    Text(score, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(movesText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ProgressView(value: min(max(score, 0), 1))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var movesText: String {
        var parts = [lookup?.moveName(moveset.fastMoveId) ?? moveset.fastMoveId]
        if let charged = moveset.chargedMoveId { parts.append(lookup?.moveName(charged) ?? charged) }
        var text = parts.joined(separator: " + ")
        if candidate.isMine {
            text += " · L\(candidate.combatant.level.description) · \(candidate.combatant.ivs.attack)/\(candidate.combatant.ivs.defense)/\(candidate.combatant.ivs.stamina)"
        }
        return text
    }
}

/// Row of "×1.60 Fire" style multiplier chips.
struct TypeMultiplierList: View {
    let items: [TypeMultiplier]

    var body: some View {
        if items.isEmpty {
            Text("None").foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        TypeBadge(type: item.type)
                        Text("×\(item.multiplier, specifier: "%.2f")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Explains the ranking. Shared by Raids and Rocket.
struct CounterMethodNote: View {
    var body: some View {
        DisclosureGroup("How this is calculated") {
            Text("""
            Each counter uses the moveset with the highest damage per second (DPS) against this opponent: \
            fast moves until there is energy for the charged move, then the charged move, repeated. \
            Damage uses the standard community formula with the type chart, same-type bonus, weather \
            bonus, shadow bonus and PvE move stats from the game master (PokeMiners).

            The opponent's real stats are held by the game's servers, so it is modelled at level 40 \
            with perfect IVs. That changes every counter's damage by about the same factor, so the \
            ranking holds, but the percentages are relative to the best counter in the list, not exact DPS.

            Not included: dodging, energy gained from taking damage, how long each counter survives, \
            and friendship or party bonuses. Moves without PvE data are skipped.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
