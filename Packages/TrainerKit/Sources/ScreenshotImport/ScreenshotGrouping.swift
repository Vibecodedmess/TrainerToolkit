import Foundation

/// Splits a batch of screenshots into one group per Pokémon.
///
/// Screenshots of one Pokémon are next to each other (the top of its screen, scrolled down, its
/// appraisal), in the order they were picked. A screenshot starts a new group when its CP, max HP,
/// name or candy family differs from what the current group has. A screenshot without any of
/// those (rare) joins the current group.
///
/// The trainer always uses at least `minimumPerPokemon` screenshots per Pokémon (their way of
/// working, 2026-11-16), so a group of one is a misread, not a Pokémon: it joins the neighbouring
/// group it disagrees with least (the one before it on a tie, as the appraisal usually comes after).
public enum ScreenshotGrouping {
    public static let minimumPerPokemon = 2

    public static func group(_ readings: [ScreenReading], minimumPerPokemon minimum: Int = minimumPerPokemon) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        var known = ScreenReading()
        for (index, r) in readings.enumerated() {
            if !current.isEmpty && conflicts(r, known) {
                groups.append(current)
                current = []
                known = ScreenReading()
            }
            current.append(index)
            known = known.merged(with: r)
        }
        if !current.isEmpty { groups.append(current) }
        return mergeSmallGroups(groups, readings: readings, minimum: minimum)
    }

    /// Folds groups smaller than `minimum` into a neighbour until none are left (or only one group remains).
    static func mergeSmallGroups(_ input: [[Int]], readings: [ScreenReading], minimum: Int) -> [[Int]] {
        var groups = input
        while groups.count > 1, let small = groups.firstIndex(where: { $0.count < minimum }) {
            let reading = combine(groups[small].map { readings[$0] })
            func cost(_ neighbour: Int) -> Int {
                conflictCount(reading, combine(groups[neighbour].map { readings[$0] }))
            }
            let before = small - 1, after = small + 1
            let target: Int
            if before < 0 { target = after }
            else if after >= groups.count { target = before }
            else { target = cost(after) < cost(before) ? after : before }
            groups[target] = (groups[target] + groups[small]).sorted()
            groups.remove(at: small)
        }
        return groups
    }

    /// One reading for a group of screenshots of the same Pokémon. CP, max HP, name and candy
    /// family are decided by majority (first seen wins a tie), so one misread screenshot doesn't
    /// override the others; everything else is filled in from the screenshots in order.
    public static func combine(_ readings: [ScreenReading]) -> ScreenReading {
        var combined = readings.reduce(ScreenReading()) { $0.merged(with: $1) }
        combined.cp = majority(readings.map(\.cp))
        combined.hp = majority(readings.map(\.hp))
        combined.name = majority(readings.map { $0.name }, key: { $0.lowercased() })
        combined.candyFamily = majority(readings.map { $0.candyFamily }, key: { $0.lowercased() })
        return combined
    }

    static func majority<T: Hashable>(_ values: [T?]) -> T? {
        majority(values, key: { $0 })
    }

    static func majority<T, K: Hashable>(_ values: [T?], key: (T) -> K) -> T? {
        var counts: [K: Int] = [:]
        var firstValue: [K: T] = [:]
        var order: [K] = []
        for case let value? in values {
            let k = key(value)
            if counts[k] == nil { order.append(k); firstValue[k] = value }
            counts[k, default: 0] += 1
        }
        guard let best = order.max(by: { counts[$0]! < counts[$1]! || (counts[$0]! == counts[$1]! && order.firstIndex(of: $0)! > order.firstIndex(of: $1)!) })
        else { return nil }
        return firstValue[best]
    }

    static func conflicts(_ a: ScreenReading, _ b: ScreenReading) -> Bool {
        conflictCount(a, b) > 0
    }

    /// How many of CP, max HP, name and candy family both readings have, with different values.
    static func conflictCount(_ a: ScreenReading, _ b: ScreenReading) -> Int {
        func differ<T: Equatable>(_ x: T?, _ y: T?) -> Int {
            guard let x, let y else { return 0 }
            return x != y ? 1 : 0
        }
        return differ(a.cp, b.cp) + differ(a.hp, b.hp)
            + differ(a.name?.lowercased(), b.name?.lowercased())
            + differ(a.candyFamily?.lowercased(), b.candyFamily?.lowercased())
    }
}

extension ScreenshotImporter.Proposal {
    public struct CertainChoice: Hashable, Sendable {
        public let option: ScreenshotImporter.SpeciesOption
        public let solution: IVSolver.Solution
    }

    /// The one answer, when there is no doubt: one species and one level/IV combination, or all
    /// three appraisal bars read and exactly one combination matching them. Nil = the user picks.
    public var certainChoice: CertainChoice? {
        guard options.count == 1, let option = options.first, let first = option.solutions.first else { return nil }
        if option.solutions.count == 1 { return CertainChoice(option: option, solution: first) }
        let allBars = barIVs.attack != nil && barIVs.defense != nil && barIVs.stamina != nil
        let exact = option.solutions.filter { $0.distance == 0 }
        if allBars && exact.count == 1 { return CertainChoice(option: option, solution: exact[0]) }
        return nil
    }
}
