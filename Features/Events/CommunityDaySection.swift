import SwiftUI
import DataSources

/// Community Day mode: what to catch, what to evolve, the exclusive move and the evolve deadline.
/// The feed has the spawns and shinies; evolutions come from PvPoke's gamemaster. The exclusive move
/// and the evolve deadline are NOT in any feed, so the trainer types them in.
struct CommunityDaySection: View {
    let event: ResolvedEvent
    let extras: EventExtras
    let lookup: GamemasterLookup?
    @Binding var exclusiveMove: String
    @Binding var deadline: Date?

    var body: some View {
        Section {
            if extras.spawns.isEmpty {
                Text("The featured Pokémon hasn't been published in the data feed yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(extras.spawns, id: \.self) { name in
                spawnRow(name)
            }
            if !extras.shinies.isEmpty {
                LabeledContent("Can be shiny", value: extras.shinies.joined(separator: ", "))
            }
        } header: {
            Text("Community Day")
        }

        Section {
            TextField("Exclusive move (from the announcement)", text: $exclusiveMove)
                .textInputAutocapitalization(.words)
            Text(candidateText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Set evolve deadline", isOn: Binding(
                get: { deadline != nil },
                set: { on in deadline = on ? (deadline ?? event.end ?? event.start ?? .now) : nil }
            ))
            if let current = deadline {
                DatePicker("Evolve by", selection: Binding(get: { current }, set: { deadline = $0 }),
                           displayedComponents: [.date, .hourAndMinute])
                Text(current > .now
                     ? "Deadline \(current.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
                     : "This deadline has passed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Exclusive move & evolve deadline")
        } footer: {
            Text("Neither is in the data feed. Copy both from the official announcement. The deadline starts at the event's end time; change it if the announcement gives a later time.")
        }
    }

    private func spawnRow(_ name: String) -> some View {
        let start = lookup?.pokemon(named: name)
        let line = start.map { lookup?.evolutionLine(from: $0) ?? [$0] } ?? []
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Catch").foregroundStyle(.secondary)
                Text(name).bold()
                Spacer()
                if let start { TypeBadges(types: start.realTypes) }
            }
            if line.count > 1 {
                Text("Evolve: " + line.map(\.speciesName).joined(separator: " → "))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    /// Elite moves PvPoke lists for the evolution line: hints only, not a statement of the CD move.
    private var candidateText: String {
        guard let lookup else { return "Pokémon data is still loading." }
        var moves: [String] = []
        for name in extras.spawns {
            guard let start = lookup.pokemon(named: name) else { continue }
            for member in lookup.evolutionLine(from: start) {
                for id in member.eliteMoves {
                    let label = "\(lookup.moveName(id)) (\(member.speciesName))"
                    if !moves.contains(label) { moves.append(label) }
                }
            }
        }
        return moves.isEmpty
            ? "PvPoke lists no elite moves for this evolution line yet."
            : "PvPoke's elite moves for this line (may include older event moves): " + moves.joined(separator: ", ")
    }
}
