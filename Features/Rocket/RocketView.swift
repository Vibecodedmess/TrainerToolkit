import SwiftUI
import DataSources

/// Team GO Rocket lineups (ScrapedDuck / LeekDuck feed). Works offline from the saved copy.
struct RocketView: View {
    @Environment(DataCenter.self) private var dataCenter

    var body: some View {
        Group {
            if dataCenter.rocketLineups.isEmpty {
                ContentUnavailableView("No Rocket lineups loaded", systemImage: "flag.2.crossed",
                                       description: Text("Pull down to refresh, or check More > Data sources."))
            } else {
                list
            }
        }
        .navigationTitle("Rocket")
        .refreshable { await dataCenter.refreshNow() }
    }

    private var list: some View {
        List {
            ForEach(Self.groups(dataCenter.rocketLineups), id: \.title) { group in
                Section(group.title) {
                    ForEach(Array(group.lineups.enumerated()), id: \.offset) { _, lineup in
                        NavigationLink {
                            RocketLineupView(lineup: lineup)
                        } label: {
                            RocketLineupRow(lineup: lineup)
                        }
                    }
                }
            }
            Section {
                Text("Lineups from ScrapedDuck (data from LeekDuck.com). Saved on the device, so this works offline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    struct LineupGroup: Hashable {
        let title: String
        let lineups: [SDRocketLineup]
    }

    /// Groups by the feed's title ("Team GO Rocket Boss", "… Leader", grunts), keeping feed order.
    static func groups(_ lineups: [SDRocketLineup]) -> [LineupGroup] {
        var order: [String] = []
        var byTitle: [String: [SDRocketLineup]] = [:]
        for l in lineups {
            let title = (l.title?.isEmpty == false ? l.title! : "Grunts")
            if byTitle[title] == nil { order.append(title) }
            byTitle[title, default: []].append(l)
        }
        return order.map { LineupGroup(title: $0, lineups: byTitle[$0] ?? []) }
    }
}

struct RocketLineupRow: View {
    let lineup: SDRocketLineup

    var body: some View {
        // Grunts have a type; leaders and the boss get the accent colour.
        let types = [lineup.type ?? ""].filter { !$0.isEmpty }
        return HStack(spacing: 10) {
            TypeStrip(types: types)
            VStack(alignment: .leading, spacing: 3) {
                Text(lineup.name).font(.headline)
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            TypeBadges(types: types)
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        [lineup.firstPokemon, lineup.secondPokemon, lineup.thirdPokemon]
            .compactMap { slot in slot.flatMap { $0.isEmpty ? nil : $0.map(\.name).joined(separator: "/") } }
            .joined(separator: " → ")
    }
}

#Preview {
    NavigationStack { RocketView() }
        .environment(DataCenter())
}
