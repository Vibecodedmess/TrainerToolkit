import SwiftUI
import DataSources

/// Current raid bosses (ScrapedDuck / LeekDuck feed), grouped by tier.
struct RaidsView: View {
    @Environment(DataCenter.self) private var dataCenter

    // Opened from More and from Home (it is no longer a tab), so it uses the caller's navigation stack.
    var body: some View {
        Group {
            if dataCenter.raids.isEmpty {
                ContentUnavailableView("No raid bosses loaded", systemImage: "shield.lefthalf.filled",
                                       description: Text("Pull down to refresh, or check More > Data sources."))
            } else {
                list
            }
        }
        .navigationTitle("Raids")
        .refreshable { await dataCenter.refreshNow() }
        .safeAreaInset(edge: .top) {
            if let warning = dataCenter.warning { WarningBanner(text: warning) }
        }
    }

    private var list: some View {
        List {
            ForEach(Self.tiers(dataCenter.raids), id: \.self) { tier in
                Section(tier) {
                    ForEach(Array(dataCenter.raids.filter { $0.tier == tier }.enumerated()), id: \.offset) { _, boss in
                        NavigationLink {
                            RaidBossDetailView(boss: boss)
                        } label: {
                            RaidBossRow(boss: boss)
                        }
                    }
                }
            }
            Section {
                Text("Raid bosses from ScrapedDuck (data from LeekDuck.com).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Tiers in display order: highest star count first, named tiers (Mega, Shadow, …) before numbered ones.
    static func tiers(_ bosses: [SDRaidBoss]) -> [String] {
        var seen: [String] = []
        for b in bosses where !seen.contains(b.tier) { seen.append(b.tier) }
        return seen.enumerated().sorted { a, b in
            let ka = sortKey(a.element), kb = sortKey(b.element)
            return ka != kb ? ka > kb : a.offset < b.offset
        }.map(\.element)
    }

    private static func sortKey(_ tier: String) -> Int {
        let digits = tier.prefix { $0.isNumber }
        return Int(digits) ?? 100
    }
}

struct RaidBossRow: View {
    let boss: SDRaidBoss

    var body: some View {
        let types = (boss.types ?? []).map { $0.name.lowercased() }
        return HStack(spacing: 10) {
            TypeStrip(types: types)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(boss.name).font(.headline)
                    if boss.canBeShiny == true {
                        Image(systemName: "sparkles").foregroundStyle(.yellow).accessibilityLabel("Can be shiny")
                    }
                    Spacer()
                    TypeBadges(types: types)
                }
                if let cp = boss.combatPower?.normal {
                    Text("CP \(cp.min)–\(cp.max)" + (boss.combatPower?.boosted.map { " · weather boosted \($0.min)–\($0.max)" } ?? ""))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { RaidsView() }
        .environment(DataCenter())
}
