import SwiftUI
import DataSources

/// Home in the "Floating dock" look: a greeting, a big Community Day countdown, round quick
/// buttons, live events side by side, the top raid tier and the next goals.
struct DockHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void
    let scan: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let cd = home.communityDay {
                    NavigationLink {
                        EventDetailView(event: cd)
                    } label: {
                        countdownCard(cd)
                    }
                    .buttonStyle(.plain)
                }
                quickButtons
                recommendedCard
                liveStrip
                raids
                goals
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(home.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(greeting)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Button {
                open(.backup)
            } label: {
                Image(systemName: home.backupIsStale ? "exclamationmark.icloud" : "checkmark.icloud")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(home.backupIsStale ? Color.orange : Color.teal)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(home.backupIsStale ? "Backup, none from the last 7 days" : "Backup, up to date")
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: home.now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Community Day

    private func countdownCard(_ cd: ResolvedEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Community Day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(cd.event.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if cd.status == .live {
                Label("Live now", systemImage: "dot.radiowaves.left.and.right")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            } else if let start = cd.start {
                let left = HomeSnapshot.timeLeft(until: start, now: home.now)
                HStack(spacing: 8) {
                    countdownBox(left.days, "days")
                    countdownBox(left.hours, "hours")
                    countdownBox(left.minutes, "min")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(HomeSnapshot.countdown(to: start, now: home.now))
                Text(start, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func countdownBox(_ value: Int, _ unit: String) -> some View {
        VStack(spacing: 0) {
            Text(value < 10 ? "0\(value)" : "\(value)")
                .font(.title.weight(.bold).monospacedDigit())
            Text(unit)
                .font(.caption2)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(minWidth: 58)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Quick buttons

    private var recommendedCard: some View {
        Button {
            open(.recommended)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.accent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended for you").font(.headline)
                    Text("Power-ups, events and raids").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .homeCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var quickButtons: some View {
        HStack(alignment: .top, spacing: 8) {
            quickButton("square.stack.3d.up", .blue, "\(home.collectionCount)", "Collection") { open(.collection) }
            quickButton("chart.line.uptrend.xyaxis", .green, "\(home.goals.count)", "Goals") { open(.planner) }
            quickButton("shield.lefthalf.filled", .red, "\(home.raidCount)", "Raids") { open(.raids) }
            quickButton("camera.viewfinder", .orange, "Scan", "Screenshots", action: scan)
        }
    }

    private func quickButton(_ systemImage: String, _ color: Color, _ value: String, _ label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(color, in: Circle())
                VStack(spacing: 0) {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Live events

    private var liveStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Happening now")
            if home.live.isEmpty {
                Text(home.eventsLoaded ? "No events running right now." : "Events haven't loaded yet.")
                    .foregroundStyle(.secondary)
                    .homeCard()
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(home.live) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                            } label: {
                                liveCard(event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)
            }
        }
    }

    private func liveCard(_ event: ResolvedEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 8, height: 8).accessibilityHidden(true)
                Text("Live").font(.caption.weight(.semibold)).foregroundStyle(.green)
            }
            Text(event.event.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
            if let end = event.end {
                Text("Ends \(end, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 210, alignment: .leading)
        .homeCard(cornerRadius: 18)
    }

    // MARK: - Raids and goals

    @ViewBuilder
    private var raids: some View {
        if let top = home.topTier {
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: top, actionTitle: "All raids") { open(.raids) }
                VStack(spacing: 8) {
                    ForEach(Array(home.topBosses.enumerated()), id: \.offset) { _, boss in
                        NavigationLink {
                            RaidBossDetailView(boss: boss)
                        } label: {
                            RaidBossRow(boss: boss).homeCard(cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var goals: some View {
        if !home.goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: "Next power-ups", actionTitle: "Planner") { open(.planner) }
                VStack(spacing: 0) {
                    ForEach(Array(home.goals.prefix(3).enumerated()), id: \.offset) { index, goal in
                        if index > 0 { Divider() }
                        HStack {
                            Text(goal.speciesName)
                            Spacer()
                            Text(HomeSnapshot.levelRange(goal))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .homeCard(cornerRadius: 18, padding: 12)
            }
        }
    }
}
