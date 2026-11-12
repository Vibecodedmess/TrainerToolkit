import SwiftUI
import SwiftData
import DataSources
import GameMath

/// Today at a glance: shortcut tiles, the next Community Day, live events, top raid bosses and goals.
struct HomeView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Query(sort: \PowerUpGoal.createdAt, order: .reverse) private var goals: [PowerUpGoal]
    @Query private var collection: [CollectedPokemon]
    @State private var destination: Destination?

    /// Where a tile leads.
    enum Destination: Hashable {
        case collection, planner, rocket, backup
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let events = EventCalendar.resolve(dataCenter.events, now: context.date)
                List {
                    tilesSection
                    communityDaySection(events, now: context.date)
                    liveSection(events)
                    raidSection
                    goalsSection
                }
            }
            .navigationTitle("Home")
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .collection: CollectionView()
                case .planner: PlannerView()
                case .rocket: RocketView()
                case .backup: BackupView()
                }
            }
            .refreshable { await dataCenter.refreshNow() }
            .safeAreaInset(edge: .top) {
                if let warning = dataCenter.warning { WarningBanner(text: warning) }
            }
        }
    }

    // MARK: - Tiles

    private var tilesSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                tile(.collection, InfoTile(systemImage: "square.stack.3d.up", color: .blue,
                                           value: Text("\(collection.count)"), label: "My collection"))
                tile(.planner, InfoTile(systemImage: "chart.line.uptrend.xyaxis", color: .green,
                                        value: Text("\(goals.count)"), label: "Power-up goals"))
                tile(.rocket, InfoTile(systemImage: "flag.2.crossed", color: .red,
                                       value: Text("\(dataCenter.rocketLineups.count)"), label: "Rocket lineups"))
                tile(.backup, backupTile)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func tile(_ target: Destination, _ content: InfoTile) -> some View {
        Button {
            destination = target
        } label: {
            content
        }
        // Plain style keeps each tile separately tappable inside one list row.
        .buttonStyle(.plain)
    }

    /// Last backup as "2 days ago"; orange when there's none from the last 7 days.
    private var backupTile: InfoTile {
        if let last = BackupManager.lastBackup {
            let stale = Date.now.timeIntervalSince(last) > 7 * 24 * 3600
            return InfoTile(systemImage: "externaldrive.badge.icloud", color: stale ? .orange : .teal,
                            value: Text(last, format: .relative(presentation: .named)), label: "Last backup",
                            valueColor: stale ? .orange : .primary)
        }
        return InfoTile(systemImage: "externaldrive.badge.icloud", color: .orange, value: Text("Never"),
                        label: "Last backup", valueColor: .orange)
    }

    // MARK: - Sections

    @ViewBuilder
    private func communityDaySection(_ events: [ResolvedEvent], now: Date) -> some View {
        if let cd = EventCalendar.nextCommunityDay(in: events) {
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
                            Text(countdown(to: start, now: now))
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

    @ViewBuilder
    private func liveSection(_ events: [ResolvedEvent]) -> some View {
        let live = EventCalendar.sortedForDisplay(events.filter { $0.status == .live })
        Section {
            if live.isEmpty {
                Text(dataCenter.events.isEmpty ? "Events haven't loaded yet." : "No events running right now.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(live.prefix(5)) { event in
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
                if live.count > 5 {
                    Text("+ \(live.count - 5) more in the Events tab").font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Happening now")
        }
    }

    @ViewBuilder
    private var raidSection: some View {
        let tiers = RaidsView.tiers(dataCenter.raids)
        if let top = tiers.first {
            Section {
                ForEach(Array(dataCenter.raids.filter { $0.tier == top }.enumerated()), id: \.offset) { _, boss in
                    NavigationLink {
                        RaidBossDetailView(boss: boss)
                    } label: {
                        RaidBossRow(boss: boss)
                    }
                }
            } header: {
                Text(top)
            } footer: {
                Text("All tiers are in the Raids tab.")
            }
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        if !goals.isEmpty {
            Section("Next power-ups") {
                ForEach(goals.prefix(3)) { goal in
                    HStack {
                        Text(goal.speciesName)
                        Spacer()
                        Text("L\(PokemonLevel(halfSteps: goal.currentLevelHalfSteps).description) → L\(PokemonLevel(halfSteps: goal.targetLevelHalfSteps).description)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// "in 3 d 4 h 12 min" countdown, minutes resolution (the view refreshes every minute).
    private func countdown(to date: Date, now: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        let days = minutes / (24 * 60)
        let hours = (minutes / 60) % 24
        let mins = minutes % 60
        return days > 0 ? "in \(days) d \(hours) h \(mins) min" : "in \(hours) h \(mins) min"
    }
}

#Preview {
    HomeView()
        .environment(DataCenter())
}
