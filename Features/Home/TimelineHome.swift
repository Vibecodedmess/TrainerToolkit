import SwiftUI
import DataSources

/// Home in the "Timeline" look: one line of what's on now and next (live events, raids, events
/// starting today or this week, goals, backup), plus a round button to add from screenshots.
struct TimelineHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void
    let scan: () -> Void

    @AppStorage("home.timeline.week") private var showWeek = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Show", selection: $showWeek) {
                    Text("Today").tag(false)
                    Text("This week").tag(true)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 0) {
                    let steps = entries
                    ForEach(steps.indices, id: \.self) { index in
                        TimelineStep(color: steps[index].color, hollow: steps[index].hollow,
                                     isLast: index == steps.count - 1) {
                            steps[index].content
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Room for the scan button over the last step.
            .padding(.bottom, 88)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            Button(action: scan) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.accent, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(20)
            .accessibilityLabel("Add to collection from screenshots")
        }
    }

    // MARK: - Steps

    private struct Entry {
        let color: Color
        var hollow = false
        let content: AnyView
    }

    /// End of the chosen range: the end of today, or 7 days from now.
    private var rangeEnd: Date {
        if showWeek { return home.now.addingTimeInterval(7 * 24 * 3600) }
        let startOfDay = Calendar.current.startOfDay(for: home.now)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? home.now
    }

    private var upcoming: [ResolvedEvent] {
        home.events
            .filter { $0.status == .upcoming && ($0.start.map { $0 < rangeEnd } ?? false) }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    private var entries: [Entry] {
        var list: [Entry] = []

        // Now: live events.
        list.append(Entry(color: .green, content: AnyView(nowStep)))

        // Raids now: the top tier.
        if !home.topBosses.isEmpty {
            list.append(Entry(color: .red, content: AnyView(raidStep)))
        }

        // Starting later today / this week.
        let next = upcoming
        if next.isEmpty {
            list.append(Entry(color: .secondary, hollow: true, content: AnyView(
                stepText(showWeek ? "This week" : "Later today",
                         title: showWeek ? "Nothing else starts this week." : "Nothing else starts today.",
                         color: .secondary)
            )))
        } else {
            for event in next.prefix(8) {
                list.append(Entry(color: event.isCommunityDay ? AppTheme.accent : .blue,
                                  content: AnyView(upcomingStep(event))))
            }
            if next.count > 8 {
                list.append(Entry(color: .secondary, hollow: true, content: AnyView(
                    Text("+ \(next.count - 8) more in the Events tab").font(.footnote).foregroundStyle(.secondary)
                )))
            }
        }

        // The Community Day, if it starts after the chosen range.
        if let cd = home.communityDay, cd.status == .upcoming, !next.contains(where: { $0.id == cd.id }) {
            list.append(Entry(color: AppTheme.accent, content: AnyView(upcomingStep(cd))))
        }

        // Your things.
        list.append(Entry(color: .purple, hollow: true, content: AnyView(recommendedStep)))
        if !home.goals.isEmpty {
            list.append(Entry(color: .green, hollow: true, content: AnyView(goalsStep)))
        }
        list.append(Entry(color: home.backupIsStale ? .orange : .teal, hollow: true, content: AnyView(backupStep)))
        return list
    }

    private func stepText(_ label: String, title: String, color: Color, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(title).foregroundStyle(.primary)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nowStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now").font(.caption.weight(.semibold)).foregroundStyle(.green)
            if home.live.isEmpty {
                Text(home.eventsLoaded ? "No events running right now." : "Events haven't loaded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(home.live.prefix(5)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.event.name).foregroundStyle(.primary).lineLimit(2)
                            if let end = event.end {
                                Text("Ends \(end, format: .relative(presentation: .named))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if home.live.count > 5 {
                    Text("+ \(home.live.count - 5) more in the Events tab").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var raidStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                open(.raids)
            } label: {
                HStack(spacing: 4) {
                    Text("Raids now · \(home.topTier ?? "")")
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All raids")

            FlowChips(items: Array(home.topBosses.enumerated()), more: max(0, home.raidCount - home.topBosses.count))
        }
    }

    private func upcomingStep(_ event: ResolvedEvent) -> some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                if let start = event.start {
                    let sameDay = Calendar.current.isDate(start, inSameDayAs: home.now)
                    let when = sameDay
                        ? start.formatted(.dateTime.hour().minute())
                        : start.formatted(.dateTime.weekday(.abbreviated).day().hour().minute())
                    Text("\(when) · \(HomeSnapshot.countdown(to: start, now: home.now))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(event.isCommunityDay ? AppTheme.accent : Color.blue)
                }
                Text(event.isCommunityDay ? "Community Day" : event.event.name)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if event.isCommunityDay {
                    Text(event.event.name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(event.isCommunityDay ? 10 : 0)
            .background {
                if event.isCommunityDay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.accent.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recommendedStep: some View {
        Button {
            open(.recommended)
        } label: {
            stepText("For you", title: "Recommended", color: .purple,
                     detail: "What to power up, which events to join and which raids to do")
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var goalsStep: some View {
        Button {
            open(.planner)
        } label: {
            stepText("Goals", title: home.goals.count == 1 ? "1 power-up waiting" : "\(home.goals.count) power-ups waiting",
                     color: .secondary,
                     detail: home.goals.prefix(2).map { "\($0.speciesName) \(HomeSnapshot.levelRange($0))" }
                         .joined(separator: " · "))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backupStep: some View {
        Button {
            open(.backup)
        } label: {
            Group {
                if let last = home.lastBackup {
                    stepText("Backup", title: "Last backup \(last.formatted(.relative(presentation: .named)))",
                             color: home.backupIsStale ? .orange : .secondary,
                             detail: "\(home.collectionCount) in your collection")
                } else {
                    stepText("Backup", title: "No backup yet", color: .orange,
                             detail: "\(home.collectionCount) in your collection")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One step on the timeline: a dot (filled, or hollow for your own things) on a line, and its content.
private struct TimelineStep<Content: View>: View {
    let color: Color
    let hollow: Bool
    let isLast: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.leading, 28)
            .padding(.bottom, isLast ? 0 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The line runs from under this dot to the next one.
            .background(alignment: .topLeading) {
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .padding(.top, 18)
                        .offset(x: 6)
                }
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .strokeBorder(color, lineWidth: hollow ? 2.5 : 0)
                    .background(Circle().fill(hollow ? Color.clear : color))
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
    }
}

/// The top raid tier as small type-coloured chips that wrap onto more lines.
private struct FlowChips: View {
    let items: [(offset: Int, element: SDRaidBoss)]
    let more: Int

    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(items, id: \.offset) { _, boss in
                NavigationLink {
                    RaidBossDetailView(boss: boss)
                } label: {
                    let types = (boss.types ?? []).map { $0.name.lowercased() }
                    let color = AppTheme.typeColor(types)
                    Text(boss.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            if more > 0 {
                Text("+ \(more) in other tiers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }
}

/// Lays children out left to right, wrapping onto a new line when the row is full.
private struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
