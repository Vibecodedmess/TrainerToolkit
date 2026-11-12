import SwiftUI
import SwiftData
import DataSources
import GameMath

/// Today at a glance: live events, the next Community Day, top raid bosses, goals and collection.
struct HomeView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Query(sort: \PowerUpGoal.createdAt, order: .reverse) private var goals: [PowerUpGoal]
    @Query private var collection: [CollectedPokemon]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let events = EventCalendar.resolve(dataCenter.events, now: context.date)
                List {
                    liveSection(events)
                    communityDaySection(events, now: context.date)
                    raidSection
                    toolsSection
                }
            }
            .navigationTitle("Home")
            .refreshable { await dataCenter.refreshNow() }
            .safeAreaInset(edge: .top) {
                if let warning = dataCenter.warning { WarningBanner(text: warning) }
            }
        }
    }

    // MARK: - Sections

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
                if live.count > 5 {
                    Text("+ \(live.count - 5) more in the Events tab").font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Happening now")
        }
    }

    @ViewBuilder
    private func communityDaySection(_ events: [ResolvedEvent], now: Date) -> some View {
        if let cd = EventCalendar.nextCommunityDay(in: events) {
            Section("Community Day") {
                NavigationLink {
                    EventDetailView(event: cd)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cd.event.name).font(.headline)
                        if cd.status == .live {
                            Label("Live now", systemImage: "dot.radiowaves.left.and.right").foregroundStyle(.green)
                        } else if let start = cd.start {
                            Text(countdown(to: start, now: now))
                                .font(.title3.monospacedDigit().weight(.semibold))
                            Text(start, format: .dateTime.weekday(.wide).day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
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

    private var toolsSection: some View {
        Section("Your plans") {
            NavigationLink {
                PlannerView()
            } label: {
                LabeledContent {
                    Text(goals.isEmpty ? "None yet" : "\(goals.count)")
                } label: {
                    Label("Power-up goals", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            ForEach(goals.prefix(3)) { goal in
                Text("\(goal.speciesName): level \(PokemonLevel(halfSteps: goal.currentLevelHalfSteps).description) → \(PokemonLevel(halfSteps: goal.targetLevelHalfSteps).description)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                CollectionView()
            } label: {
                LabeledContent {
                    Text("\(collection.count)")
                } label: {
                    Label("My collection", systemImage: "square.stack.3d.up")
                }
            }
            NavigationLink {
                BackupView()
            } label: {
                LabeledContent {
                    backupStatus
                } label: {
                    Label("Backup", systemImage: "externaldrive.badge.icloud")
                }
            }
        }
    }

    /// "2 days ago", in orange when there's no backup from the last 7 days.
    @ViewBuilder
    private var backupStatus: some View {
        if let last = BackupManager.lastBackup {
            Text(last, format: .relative(presentation: .named))
                .foregroundStyle(Date.now.timeIntervalSince(last) > 7 * 24 * 3600 ? Color.orange : Color.secondary)
        } else {
            Text("Never").foregroundStyle(.orange)
        }
    }

    /// "3 d 04:12" style countdown, minutes resolution (the view refreshes every minute).
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
