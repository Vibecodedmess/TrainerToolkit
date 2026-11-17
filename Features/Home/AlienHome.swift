import SwiftUI
import DataSources

/// Colours, font and outlines for the chunky game style of the "Alien signal" look.
enum Chunky {
    static let ink = Color(red: 0.05, green: 0.16, blue: 0.06)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.23)
    static let pink = Color(red: 1.0, green: 0.36, blue: 0.64)
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let cyan = Color(red: 0.24, green: 0.88, blue: 0.91)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.2)
    static let mutedGreen = Color(red: 0.5, green: 0.72, blue: 0.42)

    /// The system's rounded font at its heaviest weight: chunky without bundling a font.
    static func font(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded, weight: .black)
    }
}

/// A thick dark outline with a drop below it, for chunky white or coloured text.
struct ChunkyOutline: ViewModifier {
    var width: CGFloat = 1.5

    func body(content: Content) -> some View {
        content
            .shadow(color: Chunky.ink, radius: 0, x: width, y: 0)
            .shadow(color: Chunky.ink, radius: 0, x: -width, y: 0)
            .shadow(color: Chunky.ink, radius: 0, x: 0, y: width)
            .shadow(color: Chunky.ink, radius: 0, x: 0, y: -width)
            .shadow(color: Chunky.ink, radius: 0, x: 0, y: width * 2.5)
    }
}

/// A chunky button: bright fill, thick dark border and a dark lip that it presses down onto.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return configuration.label
            .foregroundStyle(Chunky.ink)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Chunky.ink, lineWidth: 3))
            .background(shape.fill(Chunky.ink).offset(y: pressed ? 1 : 5))
            .offset(y: pressed ? 4 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Home in the "Alien signal" look: chunky game-style stickers and buttons over the moving alien
/// scene.
struct AlienHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void
    let scan: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                countdown
                tiles
                live
                raids
                goals
            }
            .padding(16)
            .padding(.bottom, 8)
        }
        .background { AlienBackground() }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private func outlined(_ text: String, _ style: Font.TextStyle, color: Color = .white) -> some View {
        Text(verbatim: text)
            .font(Chunky.font(style))
            .foregroundStyle(color)
            .modifier(ChunkyOutline())
    }

    /// A white sticker with a thick border and a lip.
    private func sticker<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 4, content: content)
            .foregroundStyle(Chunky.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: shape)
            .overlay(shape.strokeBorder(Chunky.ink, lineWidth: 3))
            .background(shape.fill(Chunky.ink).offset(y: 5))
    }

    private var header: some View {
        HStack(alignment: .center) {
            outlined("Home", .largeTitle)
                .rotationEffect(.degrees(-3))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: scan) {
                Label("Scan", systemImage: "camera.viewfinder")
                    .font(Chunky.font(.subheadline))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(ChunkyButtonStyle(fill: .white, cornerRadius: 12))
            .accessibilityLabel("Add to collection from screenshots")
        }
    }

    @ViewBuilder
    private var countdown: some View {
        if let cd = home.communityDay {
            NavigationLink {
                EventDetailView(event: cd)
            } label: {
                sticker {
                    Text("Community Day").font(Chunky.font(.subheadline))
                    if cd.status == .live {
                        outlined("Live now!", .title, color: Chunky.lime)
                    } else if let start = cd.start {
                        let left = HomeSnapshot.timeLeft(until: start, now: home.now)
                        outlined("\(left.days)d \(left.hours)h \(left.minutes)m", .title, color: Chunky.lime)
                            .accessibilityLabel(HomeSnapshot.countdown(to: start, now: home.now))
                    }
                    Text(verbatim: cd.event.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Chunky.ink.opacity(0.75))
                        .lineLimit(2)
                }
                .rotationEffect(.degrees(1.5))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        } else {
            sticker {
                Text("Community Day").font(Chunky.font(.subheadline))
                Text(home.eventsLoaded ? "None announced yet." : "Events haven't loaded yet.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Chunky.ink.opacity(0.75))
            }
            .rotationEffect(.degrees(1.5))
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 16) {
            tile("Collection", "\(home.collectionCount)", Chunky.lime) { open(.collection) }
            tile("Goals", "\(home.goals.count)", Chunky.pink) { open(.planner) }
            tile("Raids", "\(home.raidCount)", Chunky.yellow) { open(.raids) }
            tile("Backup", backupText, home.backupIsStale ? Chunky.orange : Chunky.cyan, smallValue: true) {
                open(.backup)
            }
        }
    }

    private var backupText: String {
        guard let last = home.lastBackup else { return "Never" }
        return last.formatted(.relative(presentation: .named))
    }

    private func tile(_ label: String, _ value: String, _ fill: Color, smallValue: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: label).font(Chunky.font(.subheadline))
                Text(verbatim: value)
                    .font(Chunky.font(smallValue ? .headline : .title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChunkyButtonStyle(fill: fill))
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String, action: (title: String, run: () -> Void)? = nil) -> some View {
        HStack(alignment: .center) {
            outlined(title, .title3)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let action {
                Button(action: action.run) {
                    Text(verbatim: action.title)
                        .font(Chunky.font(.footnote))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                }
                .buttonStyle(ChunkyButtonStyle(fill: .white, cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var live: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Happening now")
            if home.live.isEmpty {
                sticker {
                    Text(home.eventsLoaded ? "No events running right now." : "Events haven't loaded yet.")
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                ForEach(home.live.prefix(3)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        sticker {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(Color.green).overlay(Circle().strokeBorder(Chunky.ink, lineWidth: 2))
                                    .frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: event.event.name)
                                        .font(.subheadline.weight(.bold))
                                        .lineLimit(2)
                                    if let end = event.end {
                                        Text("Ends \(end, format: .relative(presentation: .named))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Chunky.ink.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if home.live.count > 3 {
                    outlined("+ \(home.live.count - 3) more in Events", .footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var raids: some View {
        if let tier = home.topTier {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(tier, action: ("All", { open(.raids) }))
                ForEach(Array(home.topBosses.prefix(4).enumerated()), id: \.offset) { index, boss in
                    let types = (boss.types ?? []).map { $0.name.lowercased() }
                    NavigationLink {
                        RaidBossDetailView(boss: boss)
                    } label: {
                        sticker {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(AppTheme.typeColor(types))
                                    .overlay(Circle().strokeBorder(Chunky.ink, lineWidth: 2.5))
                                    .frame(width: 26, height: 26)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        Text(verbatim: boss.name)
                                            .font(Chunky.font(.headline))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        if boss.canBeShiny == true {
                                            Image(systemName: "sparkles").foregroundStyle(.yellow)
                                                .accessibilityLabel("Can be shiny")
                                        }
                                    }
                                    Text(verbatim: types.map(\.capitalized).joined(separator: " · "))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Chunky.ink.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.heavy))
                                    .accessibilityHidden(true)
                            }
                        }
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var goals: some View {
        if !home.goals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Next power-ups", action: ("Planner", { open(.planner) }))
                Button {
                    open(.planner)
                } label: {
                    sticker {
                        ForEach(Array(home.goals.prefix(3).enumerated()), id: \.offset) { _, goal in
                            HStack {
                                Text(verbatim: goal.speciesName).font(.subheadline.weight(.bold))
                                Spacer()
                                Text(verbatim: HomeSnapshot.levelRange(goal))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Chunky.ink.opacity(0.7))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The "Alien signal" tab bar: dark green, with the selected tab in a lime block.
struct AlienTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(active ? Chunky.ink : Chunky.mutedGreen)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Chunky.lime)
                                    .padding(.horizontal, 10)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Chunky.ink.opacity(0.95))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}
