import SwiftUI
import SwiftData
import DataSources
import GameMath

/// Today at a glance, in the look picked in More > Looks. Every look shows the same data
/// (`HomeSnapshot`) and uses the same navigation.
struct HomeView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PowerUpGoal.createdAt, order: .reverse) private var goals: [PowerUpGoal]
    @Query private var collection: [CollectedPokemon]
    @AppStorage(AppLook.storageKey) private var look: AppLook = .standard
    @State private var destination: Destination?
    @State private var showingScan = false

    /// Where a tile or quick button leads.
    enum Destination: Hashable {
        case collection, planner, raids, backup, recommended
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let home = HomeSnapshot(now: context.date, feed: dataCenter.events, raids: dataCenter.raids,
                                        goals: goals, collectionCount: collection.count,
                                        lastBackup: BackupManager.lastBackup)
                let open: (Destination) -> Void = { destination = $0 }
                switch look {
                case .standard:
                    StandardHome(home: home, open: open)
                case .dock:
                    DockHome(home: home, open: open, scan: { showingScan = true })
                case .widgets:
                    WidgetBoardHome(home: home, open: open)
                case .timeline:
                    TimelineHome(home: home, open: open, scan: { showingScan = true })
                case .terminal:
                    TerminalHome(home: home, open: open, scan: { showingScan = true })
                case .alien:
                    AlienHome(home: home, open: open, scan: { showingScan = true })
                case .alienTerminal:
                    TerminalHome(home: home, open: open, scan: { showingScan = true }, alien: true)
                }
            }
            .navigationTitle(look == .widgets ? "Today" : "Home")
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .collection: CollectionView()
                case .planner: PlannerView()
                case .raids: RaidsView()
                case .backup: BackupView()
                case .recommended: RecommendedView()
                }
            }
            .refreshable { await dataCenter.refreshNow() }
            .safeAreaInset(edge: .top) {
                if let warning = dataCenter.warning { WarningBanner(text: warning) }
            }
        }
        .sheet(isPresented: $showingScan) {
            NavigationStack {
                ScreenshotImportView()
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
    }
}

// MARK: - Standard look (Phase 16)

/// Shortcut tiles, the next Community Day, live events, top raid bosses and goals, as a list.
private struct StandardHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void

    var body: some View {
        List {
            tilesSection
            Section {
                Button {
                    open(.recommended)
                } label: {
                    HStack {
                        Label("Recommended for you", systemImage: "wand.and.stars")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } footer: {
                Text("What to power up, which events to join and which raids to do.")
            }
            communityDaySection
            liveSection
            raidSection
            goalsSection
        }
    }

    private var tilesSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                tile(.collection, InfoTile(systemImage: "square.stack.3d.up", color: .blue,
                                           value: Text("\(home.collectionCount)"), label: "My collection"))
                tile(.planner, InfoTile(systemImage: "chart.line.uptrend.xyaxis", color: .green,
                                        value: Text("\(home.goals.count)"), label: "Power-up goals"))
                // Raids moved off the tab bar (Rocket took its place), so Home keeps a shortcut to it.
                tile(.raids, InfoTile(systemImage: "shield.lefthalf.filled", color: .red,
                                      value: Text("\(home.raidCount)"), label: "Raid bosses"))
                tile(.backup, backupTile)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func tile(_ target: HomeView.Destination, _ content: InfoTile) -> some View {
        Button {
            open(target)
        } label: {
            content
        }
        // Plain style keeps each tile separately tappable inside one list row.
        .buttonStyle(.plain)
    }

    /// Last backup as "2 days ago"; orange when there's none from the last 7 days.
    private var backupTile: InfoTile {
        if let last = home.lastBackup {
            let stale = home.backupIsStale
            return InfoTile(systemImage: "externaldrive.badge.icloud", color: stale ? .orange : .teal,
                            value: Text(last, format: .relative(presentation: .named)), label: "Last backup",
                            valueColor: stale ? .orange : .primary)
        }
        return InfoTile(systemImage: "externaldrive.badge.icloud", color: .orange, value: Text("Never"),
                        label: "Last backup", valueColor: .orange)
    }

    @ViewBuilder
    private var communityDaySection: some View {
        if let cd = home.communityDay {
            Section("Community Day") {
                NavigationLink {
                    EventDetailView(event: cd)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cd.event.name).font(.subheadline).foregroundStyle(.secondary)
                        if cd.status == .live {
                            Label("Live now", systemImage: "dot.radiowaves.left.and.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.green)
                        } else if let start = cd.start {
                            Text(HomeSnapshot.countdown(to: start, now: home.now))
                                .font(.title2.monospacedDigit().weight(.bold))
                            Text(start, format: .dateTime.weekday(.wide).day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.accent.opacity(0.14))
            }
        }
    }

    private var liveSection: some View {
        Section {
            if home.live.isEmpty {
                Text(home.eventsLoaded ? "No events running right now." : "Events haven't loaded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(home.live.prefix(5)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.event.name).lineLimit(2)
                                if let end = event.end {
                                    Text("Ends \(end, format: .relative(presentation: .named))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if home.live.count > 5 {
                    Text("+ \(home.live.count - 5) more in the Events tab").font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Happening now")
        }
    }

    @ViewBuilder
    private var raidSection: some View {
        if let top = home.topTier {
            Section {
                ForEach(Array(home.topBosses.enumerated()), id: \.offset) { _, boss in
                    NavigationLink {
                        RaidBossDetailView(boss: boss)
                    } label: {
                        RaidBossRow(boss: boss)
                    }
                }
            } header: {
                Text(top)
            } footer: {
                Text("All tiers: tap the Raid bosses tile above, or More > Raids.")
            }
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        if !home.goals.isEmpty {
            Section("Next power-ups") {
                ForEach(home.goals.prefix(3)) { goal in
                    HStack {
                        Text(goal.speciesName)
                        Spacer()
                        Text(HomeSnapshot.levelRange(goal))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(DataCenter())
}
