import Foundation

/// Splits a batch of screenshots into one group per Pokémon.
///
/// Screenshots of one Pokémon are next to each other (the top of its screen, scrolled down, its
/// appraisal), in the order they were picked. A screenshot starts a new group when its CP, max HP,
/// name or candy family differs from what the current group has. A screenshot without any of
/// those (rare) joins the current group.
public enum ScreenshotGrouping {
    public static func group(_ readings: [ScreenReading]) -> [[Int]] {
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
        return groups
    }

    static func conflicts(_ a: ScreenReading, _ b: ScreenReading) -> Bool {
        func differ<T: Equatable>(_ x: T?, _ y: T?) -> Bool {
            guard let x, let y else { return false }
            return x != y
        }
        return differ(a.cp, b.cp) || differ(a.hp, b.hp)
            || differ(a.name?.lowercased(), b.name?.lowercased())
            || differ(a.candyFamily?.lowercased(), b.candyFamily?.lowercased())
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
