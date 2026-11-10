import SwiftUI
import SwiftData
import DataSources

struct EventsView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Query private var checklist: [ChecklistItem]
    @AppStorage("events.showEnded") private var showEnded = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let resolved = EventCalendar.sortedForDisplay(EventCalendar.resolve(dataCenter.events, now: context.date))
                content(resolved, now: context.date)
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Show recently ended", isOn: $showEnded)
                    } label: {
                        Label("Options", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await dataCenter.refreshNow() }
            .task(id: dataCenter.events.map(\.eventID)) {
                await ReminderScheduler.sync(context: modelContext, events: EventCalendar.resolve(dataCenter.events))
            }
        }
    }

    @ViewBuilder
    private func content(_ events: [ResolvedEvent], now: Date) -> some View {
        if events.isEmpty {
            ContentUnavailableView("No events loaded", systemImage: "calendar",
                                   description: Text("Pull down to refresh, or check More > Data sources."))
        } else {
            let progress = checklistProgress
            List {
                if let warning = dataCenter.warning {
                    Section { WarningBanner(text: warning).listRowInsets(EdgeInsets()) }
                }
                section("Live now", events.filter { $0.status == .live }, progress: progress, now: now)
                section("Upcoming", events.filter { $0.status == .upcoming }, progress: progress, now: now)
                section("Dates not announced", events.filter { $0.status == .undated }, progress: progress, now: now)
                if showEnded {
                    let cutoff = now.addingTimeInterval(-14 * 24 * 3600)
                    section("Ended (last 14 days)",
                            events.filter { $0.status == .ended && ($0.end ?? .distantPast) > cutoff },
                            progress: progress, now: now)
                }
                Section {
                } footer: {
                    Text("Event data from ScrapedDuck / LeekDuck.com. Times are shown in your time zone.")
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ events: [ResolvedEvent], progress: [String: (done: Int, total: Int)], now: Date) -> some View {
        if !events.isEmpty {
            Section(title) {
                ForEach(events) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        EventRow(event: event, progress: progress[event.id], now: now)
                    }
                }
            }
        }
    }

    private var checklistProgress: [String: (done: Int, total: Int)] {
        var result: [String: (done: Int, total: Int)] = [:]
        for item in checklist {
            let current = result[item.eventID] ?? (0, 0)
            result[item.eventID] = (current.done + (item.isDone ? 1 : 0), current.total + 1)
        }
        return result
    }
}

private struct EventRow: View {
    let event: ResolvedEvent
    let progress: (done: Int, total: Int)?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.event.name)
                    .font(.headline)
                if event.isCommunityDay {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Community Day")
                }
            }
            Text(event.event.heading ?? event.event.eventType)
                .font(.caption)
                .foregroundStyle(.secondary)
            timing
                .font(.subheadline)
            if let progress, progress.total > 0 {
                Label("\(progress.done)/\(progress.total) tasks", systemImage: progress.done == progress.total ? "checkmark.circle.fill" : "checklist")
                    .font(.caption)
                    .foregroundStyle(progress.done == progress.total ? Color.green : Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var timing: some View {
        switch event.status {
        case .live:
            if let end = event.end {
                Text("Ends \(end.formatted(.relative(presentation: .named, unitsStyle: .wide)))")
                    .foregroundStyle(.green)
            } else {
                Text("Live now").foregroundStyle(.green)
            }
        case .upcoming:
            if let start = event.start {
                HStack(spacing: 4) {
                    Text(EventFormat.dateTime(start))
                    if event.isGlobalTime {
                        Image(systemName: "globe")
                            .accessibilityLabel("Same time worldwide")
                    }
                }
            }
        case .undated:
            Text("Date to be announced").foregroundStyle(.secondary)
        case .ended:
            Text("Ended").foregroundStyle(.secondary)
        }
    }
}

enum EventFormat {
    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}

#Preview {
    EventsView()
        .environment(DataCenter())
        .modelContainer(for: [EventPlan.self, ChecklistItem.self], inMemory: true)
}
