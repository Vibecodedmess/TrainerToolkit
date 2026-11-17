import Foundation
import DataSources
import GameMath

/// "Recommended": which of your Pokémon to power up, which events to join and which raid bosses to
/// do. Only data the app already has (your collection and goals, the event and raid feeds, the game
/// master tables) and the same damage model as the raid screens. Nothing is made up: a reason is
/// shown only when the data supports it.
public enum Recommender {

    // MARK: - Power-ups

    public struct PowerUpPick: Sendable, Hashable, Identifiable {
        public let candidate: CounterCandidate
        /// The next comparison level above its current one (40, 45 or 50).
        public let target: PokemonLevel
        /// Current raid bosses (indexes into `defenders`) where, at `target`, it gets into your best
        /// `teamSize` without being in it now.
        public let joinsTeam: [Int]
        /// Bosses where, at `target`, it becomes your best counter without being it now.
        public let becomesBest: [Int]
        public var id: String { candidate.id }
        /// More bosses first; becoming your best counts double.
        public var score: Int { joinsTeam.count + 2 * becomesBest.count }
    }

    /// The level to compare against: the next of 40, 45 and 50 above `current`, up to `maxLevel`.
    public static func nextTarget(from current: PokemonLevel, maxLevel: PokemonLevel) -> PokemonLevel? {
        PowerUpValue.comparisonLevels(from: current, maxLevel: maxLevel).dropFirst().first
    }

    /// Your Pokémon whose next power-up step makes the biggest difference against the current
    /// raid bosses. Everyone else stays at their own level.
    public static func powerUps(_ team: [CounterCandidate], defenders: [Combatant], weather: String?,
                                teamSize: Int = 6, tables: LevelTables, battle: BattleTables) -> [PowerUpPick] {
        guard team.count > teamSize, !defenders.isEmpty else { return [] }
        func dps(_ c: CounterCandidate, level: PokemonLevel? = nil, _ defender: Combatant) -> Double {
            var combatant = c.combatant
            if let level { combatant.level = level }
            return DamageCalculator.bestMoveset(attacker: combatant, fastMoveIds: c.fastMoveIds, chargedMoveIds: c.chargedMoveIds,
                                                defender: defender, weather: weather, levels: tables, battle: battle)?.dps ?? 0
        }
        // Everyone's DPS now, per defender.
        let now: [[Double]] = defenders.map { d in team.map { dps($0, d) } }

        var picks: [PowerUpPick] = []
        for (i, c) in team.enumerated() {
            guard let target = nextTarget(from: c.combatant.level, maxLevel: tables.maxUpgradeLevel) else { continue }
            var joins: [Int] = [], best: [Int] = []
            for (d, defender) in defenders.enumerated() {
                let mine = now[d][i]
                let after = dps(c, level: target, defender)
                guard after > 0 else { continue }
                let others = now[d].enumerated().filter { $0.offset != i }.map(\.element)
                let rankNow = 1 + others.filter { $0 > mine }.count
                let rankAfter = 1 + others.filter { $0 > after }.count
                if mine > 0, rankNow <= teamSize {
                    if rankNow > 1 && rankAfter == 1 { best.append(d) }
                } else if rankAfter <= teamSize {
                    joins.append(d)
                    if rankAfter == 1 { best.append(d) }
                }
            }
            if !joins.isEmpty || !best.isEmpty {
                picks.append(PowerUpPick(candidate: c, target: target, joinsTeam: joins, becomesBest: best))
            }
        }
        return picks.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.candidate.combatant.level > $1.candidate.combatant.level
        }
    }

    // MARK: - Events

    public struct EventPick: Sendable, Hashable, Identifiable {
        public let event: ResolvedEvent
        /// Featured Pokémon in the same family as one of your power-up goals (their candy helps).
        public let forGoals: [String]
        /// Featured Pokémon you don't have in your collection yet (by Pokédex number).
        public let new: [String]
        /// Shiny-eligible Pokémon, as listed by the feed.
        public let shinies: [String]
        /// Event bonuses, as listed by the feed.
        public let bonuses: [String]
        /// Special Research rewards, as listed by the feed.
        public let rewards: [String]
        public var id: String { event.id }
        public var score: Int {
            3 * forGoals.count + 2 * new.count + shinies.count + (bonuses.isEmpty ? 0 : 1) + (rewards.isEmpty ? 0 : 1)
        }
    }

    /// Live events, and upcoming ones starting within `horizon`, that have something for you.
    public static func events(_ events: [ResolvedEvent], now: Date, horizon: TimeInterval = 7 * 24 * 3600,
                              goalSpeciesIds: Set<String>, ownedSpeciesIds: Set<String>,
                              lookup: GamemasterLookup) -> [EventPick] {
        let goalFamilies = Set(goalSpeciesIds.compactMap { lookup.pokemon(id: $0).map(familyKey) })
        let ownedDex = Set(ownedSpeciesIds.compactMap { lookup.pokemon(id: $0)?.dex })
        let limit = now.addingTimeInterval(horizon)

        let picks: [EventPick] = events.compactMap { event in
            switch event.status {
            case .live: break
            case .upcoming: guard let start = event.start, start <= limit else { return nil }
            case .ended, .undated: return nil
            }
            let extras = event.event.extras
            let featured = unique(extras.spawns + extras.featured + extras.raidBosses.map(\.name))
            var forGoals: [String] = [], new: [String] = []
            for name in featured {
                guard let p = CounterRanker.resolve(name, lookup: lookup) else { continue }
                if goalFamilies.contains(familyKey(p)) { forGoals.append(name) }
                if !ownedDex.contains(p.dex) { new.append(name) }
            }
            let shinies = unique(extras.shinies + extras.raidBosses.filter(\.canBeShiny).map(\.name))
            var bonuses = extras.bonuses
            if let spotlight = extras.spotlightBonus { bonuses.append(spotlight) }
            let rewards = unique(extras.specialResearch.flatMap { $0.rewards + $0.tasks.map(\.reward) })
            let pick = EventPick(event: event, forGoals: forGoals, new: new, shinies: shinies,
                                 bonuses: unique(bonuses), rewards: rewards)
            return pick.score > 0 ? pick : nil
        }
        return picks.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return ($0.event.start ?? .distantFuture) < ($1.event.start ?? .distantFuture)
        }
    }

    // MARK: - Raids

    public struct RaidPick: Sendable, Hashable, Identifiable {
        public let boss: SDRaidBoss
        public let pokemon: GMPokemon
        /// Best-case trainers needed with your best `teamSize`; nil when not estimated.
        public let trainers: Int?
        /// Why there's no estimate (the tier's note), when the tier isn't estimated.
        public let notEstimated: String?
        /// Your best counters against it, best first (up to 3).
        public let topCounters: [CounterCandidate]
        /// You don't have this Pokémon (by Pokédex number).
        public let isNew: Bool
        public let canBeShiny: Bool
        public var id: String { boss.name + "|" + boss.tier }
    }

    /// Current raid bosses, easiest for your collection first. Bosses with no estimate come last.
    public static func raids(_ bosses: [SDRaidBoss], team: [CounterCandidate], ownedSpeciesIds: Set<String>,
                             table: RaidEstimate.Table, weather: String?, teamSize: Int = 6,
                             lookup: GamemasterLookup, levels: LevelTables, battle: BattleTables) -> [RaidPick] {
        let ownedDex = Set(ownedSpeciesIds.compactMap { lookup.pokemon(id: $0)?.dex })
        let picks: [RaidPick] = bosses.compactMap { boss in
            guard let p = CounterRanker.resolve(boss.name, lookup: lookup) else { return nil }
            let defender = CounterRanker.defender(p, isShadow: boss.tier.lowercased().contains("shadow"))
            let ranked = CounterRanker.rank(team, against: defender, weather: weather, levels: levels, battle: battle)
            let party = ranked.prefix(teamSize).map(\.candidate)
            let tier = table.tier(forFeedTier: boss.tier)
            var trainers: Int?
            if let tier, tier.estimate {
                trainers = RaidEstimate.estimate(party: Array(party), bossBase: p.stats, bossTypes: p.realTypes, tier: tier,
                                                 weather: weather, levels: levels, battle: battle)?.trainers
            }
            return RaidPick(boss: boss, pokemon: p, trainers: trainers,
                            notEstimated: tier.flatMap { $0.estimate ? nil : ($0.note ?? "") },
                            topCounters: Array(party.prefix(3)), isNew: !ownedDex.contains(p.dex),
                            canBeShiny: boss.canBeShiny == true)
        }
        return picks.sorted { a, b in
            switch (a.trainers, b.trainers) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                if a.isNew != b.isNew { return a.isNew }
                return a.canBeShiny && !b.canBeShiny
            }
        }
    }

    // MARK: - Helpers

    /// A Pokémon's family (shared candy), or its own id when the data has no family.
    static func familyKey(_ p: GMPokemon) -> String { p.family?.id ?? p.speciesId }

    static func unique(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
