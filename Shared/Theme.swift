import SwiftUI
import GameMath

/// The app's look in one place: the accent colour, type colours and the shared stat pieces.
/// The accent itself lives in Resources/Assets.xcassets/AccentColor.colorset (light and dark).
enum AppTheme {
    static let accent = Color.accentColor

    /// A Pokémon's colour: its first type's colour (this app's own palette, see `TypeBadge`).
    static func typeColor(_ types: [String]) -> Color {
        types.first.map { TypeBadge.color(for: $0) } ?? accent
    }
}

/// CP, level and IVs in one line: "CP 2651 · L30 · 13/15/14 · 93%" (Attack/Defense/HP).
enum PokemonStats {
    static func line(cp: Int?, level: PokemonLevel, ivs: IVs) -> String {
        var parts: [String] = []
        if let cp { parts.append("CP \(cp)") }
        parts.append("L\(level.description)")
        parts.append("\(ivs.attack)/\(ivs.defense)/\(ivs.stamina)")
        parts.append("\(ivs.percent)%")
        return parts.joined(separator: " · ")
    }

    static func accessibilityLabel(cp: Int?, level: PokemonLevel, ivs: IVs) -> String {
        var parts: [String] = []
        if let cp { parts.append("CP \(cp)") }
        parts.append("level \(level.description)")
        parts.append("IVs attack \(ivs.attack), defense \(ivs.defense), HP \(ivs.stamina), \(ivs.percent) percent")
        return parts.joined(separator: ", ")
    }
}

/// The stats line as text, with digits that don't jump around.
struct StatsLineText: View {
    let cp: Int?
    let level: PokemonLevel
    let ivs: IVs

    var body: some View {
        Text(PokemonStats.line(cp: cp, level: level, ivs: ivs))
            .font(.subheadline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(PokemonStats.accessibilityLabel(cp: cp, level: level, ivs: ivs))
    }
}

/// A thin rounded bar, filled to `value` (0…1) in a colour.
struct MeterBar: View {
    let value: Double
    var color: Color = AppTheme.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                if clamped > 0 {
                    Capsule().fill(color)
                        .frame(width: max(height, geo.size.width * clamped))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A slim vertical strip in a type colour, for the leading edge of a row.
struct TypeStrip: View {
    let types: [String]

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(AppTheme.typeColor(types))
            .frame(width: 4)
            .accessibilityHidden(true)
    }
}

/// A small card for the Home screen: icon, a big value and a label.
struct InfoTile: View {
    let systemImage: String
    let color: Color
    let value: Text
    let label: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            value
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
