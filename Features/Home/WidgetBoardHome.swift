import SwiftUI
import DataSources

/// Home in the "Widget board" look: mixed-size widgets, like an iPhone home screen.
/// A tall Community Day countdown, small counters, a wide raid widget, events, backup and goals.
struct WidgetBoardHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void

    private let spacing: CGFloat = 12
    private let radius: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                HStack(alignment: .top, spacing: spacing) {
                    communityDayWidget
                        .frame(maxHeight: .infinity)
                    VStack(spacing: spacing) {
                        smallWidget("square.stack.3d.up", .blue, Text("\(home.collectionCount)"), "In your collection") {
                            open(.collection)
                        }
                        smallWidget("chart.line.uptrend.xyaxis", .green, Text("\(home.goals.count)"), "Power-up goals") {
                            open(.planner)
                        }
                    }
                }
                // The tall widget matches the two small ones, at any text size.
                .fixedSize(horizontal: false, vertical: true)

                raidWidget

                HStack(alignment: .top, spacing: spacing) {
                    eventsWidget.frame(maxHeight: .infinity)
                    backupWidget.frame(maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)

                goalsWidget
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Widgets

    private func widget<Content: View>(tint: Color? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(tint.map { $0.opacity(0.15) } ?? Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func widgetTitle(_ title: String, _ systemImage: String, _ color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
    }

    @ViewBuilder
    private var communityDayWidget: some View {
        if let cd = home.communityDay {
            NavigationLink {
                EventDetailView(event: cd)
            } label: {
                widget(tint: AppTheme.accent) {
                    widgetTitle("Community Day", "calendar.badge.clock", AppTheme.accent)
                    Text(cd.event.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if cd.status == .live {
                        Text("Live now")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.green)
                    } else if let start = cd.start {
                        let left = HomeSnapshot.timeLeft(until: start, now: home.now)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(left.days)d").font(.largeTitle.weight(.bold))
                            Text("\(left.hours)h").font(.title.weight(.bold))
                            Text("\(left.minutes)m").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(HomeSnapshot.countdown(to: start, now: home.now))
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        } else {
            widget(tint: AppTheme.accent) {
                widgetTitle("Community Day", "calendar.badge.clock", AppTheme.accent)
                Spacer(minLength: 4)
                Text(home.eventsLoaded ? "None announced yet." : "Events haven't loaded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func smallWidget(_ systemImage: String, _ color: Color, _ value: Text, _ label: String,
                             valueColor: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            widget {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                value
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var raidWidget: some View {
        widget {
            Button {
                open(.raids)
            } label: {
                HStack {
                    widgetTitle(home.topTier ?? "Raids", "shield.lefthalf.filled", .red)
                    Spacer()
                    Text("\(home.raidCount) bosses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All raids, \(home.raidCount) bosses")

            if home.topBosses.isEmpty {
                Text("Raid bosses haven't loaded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(home.topBosses.prefix(4).enumerated()), id: \.offset) { _, boss in
                        NavigationLink {
                            RaidBossDetailView(boss: boss)
                        } label: {
                            bossChip(boss)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
                if home.topBosses.count > 4 {
                    Text("+ \(home.topBosses.count - 4) more in this tier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func bossChip(_ boss: SDRaidBoss) -> some View {
        let types = (boss.types ?? []).map { $0.name.lowercased() }
        let color = AppTheme.typeColor(types)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(boss.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if boss.canBeShiny == true {
                    Image(systemName: "sparkles").font(.caption2).foregroundStyle(.yellow)
                        .accessibilityLabel("Can be shiny")
                }
            }
            Text(types.map(\.capitalized).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var eventsWidget: some View {
        let content = widget {
            widgetTitle("Happening now", "dot.radiowaves.left.and.right", .green)
            if let first = home.live.first {
                Text(first.event.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(home.live.count > 1 ? "+ \(home.live.count - 1) more live" : "Live now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(home.eventsLoaded ? "Nothing running right now." : "Events haven't loaded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        if let first = home.live.first {
            NavigationLink {
                EventDetailView(event: first)
            } label: {
                content.accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var backupWidget: some View {
        Button {
            open(.backup)
        } label: {
            widget {
                widgetTitle("Backup", "externaldrive.badge.icloud", home.backupIsStale ? .orange : .teal)
                if let last = home.lastBackup {
                    Text(home.backupIsStale ? "Due" : "Backed up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(home.backupIsStale ? Color.orange : Color.primary)
                    Spacer(minLength: 0)
                    Text(last, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer(minLength: 0)
                    Text("Tap to back up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var goalsWidget: some View {
        if !home.goals.isEmpty {
            Button {
                open(.planner)
            } label: {
                widget {
                    widgetTitle("Next power-ups", "chart.line.uptrend.xyaxis", .green)
                    ForEach(Array(home.goals.prefix(3).enumerated()), id: \.offset) { _, goal in
                        HStack {
                            Text(goal.speciesName).lineLimit(1)
                            Spacer()
                            Text(HomeSnapshot.levelRange(goal))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        }
    }
}
