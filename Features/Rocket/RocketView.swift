import SwiftUI
import DataSources
import Counters

/// What Rocket members say before a battle (the game's own text). A grunt's line gives away its type.
enum RocketData {
    static let quotes: RocketQuotes? = try? RocketQuotes.bundled()

    static func lines(for lineup: SDRocketLineup) -> [String] {
        quotes?.lines(name: lineup.name, type: lineup.type, title: lineup.title) ?? []
    }

    /// Everything a search can match: the lines, name, title, type and the Pokémon it may use.
    static func searchText(for lineup: SDRocketLineup) -> String {
        let pokemon = [lineup.firstPokemon, lineup.secondPokemon, lineup.thirdPokemon]
            .flatMap { $0 ?? [] }.map(\.name)
        return (lines(for: lineup) + [lineup.name, lineup.title ?? "", lineup.type ?? ""] + pokemon).joined(separator: " ")
    }
}

/// Team GO Rocket lineups (ScrapedDuck / LeekDuck feed). Works offline from the saved copy.
struct RocketView: View {
    @Environment(DataCenter.self) private var dataCenter
    @State private var query = ""

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
        .searchable(text: $query, prompt: "What they said, a name or a Pokémon")
        .refreshable { await dataCenter.refreshNow() }
    }

    private var filtered: [SDRocketLineup] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return dataCenter.rocketLineups }
        return dataCenter.rocketLineups.filter { RocketQuotes.matches(q, in: RocketData.searchText(for: $0)) }
    }

    private var list: some View {
        let shown = filtered
        return List {
            ForEach(Self.groups(shown), id: \.title) { group in
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lineups from ScrapedDuck (data from LeekDuck.com). Saved on the device, so this works offline.")
                    Text("What they say is the game's own text (PokeMiners). Type a few words of a grunt's line in the search to find its type.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if shown.isEmpty { ContentUnavailableView.search(text: query) }
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
                if let said = saidText {
                    Text(said).font(.subheadline).italic().lineLimit(2)
                }
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            TypeBadges(types: types)
        }
        .padding(.vertical, 2)
    }

    /// The line it says, in quotes; for grunts without a type, a note that it's one of the generic lines.
    private var saidText: String? {
        let lines = RocketData.lines(for: lineup)
        switch lines.count {
        case 0: return nil
        case 1: return "“\(lines[0])”"
        default: return "Says one of \(lines.count) general lines (no type hint)"
        }
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
