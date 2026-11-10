import SwiftUI
import DataSources

/// Searchable list of every Pokémon from the gamemaster (text names and type badges only).
struct SpeciesPicker: View {
    let candidates: [GMPokemon]
    let onPick: (GMPokemon) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [GMPokemon] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return candidates }
        if let number = Int(q) { return candidates.filter { $0.dex == number } }
        return candidates.filter { $0.speciesName.lowercased().contains(q) || $0.speciesId.contains(q) }
    }

    var body: some View {
        List(filtered) { pokemon in
            Button {
                onPick(pokemon)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pokemon.speciesName)
                            .foregroundStyle(.primary)
                        Text("#\(pokemon.dex) · \(pokemon.baseStats.atk)/\(pokemon.baseStats.def)/\(pokemon.baseStats.hp)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TypeBadges(types: pokemon.realTypes)
                }
            }
            .accessibilityHint("Base attack, defense and stamina shown")
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or Pokédex number")
        .navigationTitle("Choose Pokémon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
