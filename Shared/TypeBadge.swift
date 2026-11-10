import SwiftUI

/// Text badge for a Pokémon type ("fire", "water", ...). Colours are this app's own palette.
struct TypeBadge: View {
    let type: String

    var body: some View {
        Text(type.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.primary)
            .background(Self.color(for: type).opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.color(for: type).opacity(0.6), lineWidth: 1))
            .accessibilityLabel("\(type) type")
    }

    static func color(for type: String) -> Color {
        switch type.lowercased() {
        case "normal": return .gray
        case "fire": return .orange
        case "water": return .blue
        case "grass": return .green
        case "electric": return .yellow
        case "ice": return .cyan
        case "fighting": return .red
        case "poison": return .purple
        case "ground": return .brown
        case "flying": return .indigo
        case "psychic": return .pink
        case "bug": return .mint
        case "rock": return Color(red: 0.6, green: 0.5, blue: 0.3)
        case "ghost": return Color(red: 0.4, green: 0.3, blue: 0.6)
        case "dragon": return Color(red: 0.3, green: 0.3, blue: 0.9)
        case "dark": return Color(red: 0.35, green: 0.3, blue: 0.3)
        case "steel": return Color(red: 0.55, green: 0.6, blue: 0.7)
        case "fairy": return Color(red: 0.95, green: 0.55, blue: 0.8)
        default: return .secondary
        }
    }
}

struct TypeBadges: View {
    let types: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(types, id: \.self) { TypeBadge(type: $0) }
        }
    }
}

#Preview {
    TypeBadges(types: ["fire", "flying", "dragon"])
}
