import SwiftUI
import SwiftData
import UIKit
import DataSources

struct EventDetailView: View {
    let event: ResolvedEvent

    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [EventPlan]
    @State private var notificationsDenied = false

    init(event: ResolvedEvent) {
        self.event = event
        let id = event.id
        _plans = Query(filter: #Predicate<EventPlan> { $0.eventID == id })
    }

    private var plan: EventPlan? { plans.first }
    private var extras: EventExtras { event.event.extras }

    var body: some View {
        List {
            timeSection
            if event.isCommunityDay {
                CommunityDaySection(event: event, extras: extras, lookup: dataCenter.lookup,
                                    exclusiveMove: binding(\.exclusiveMove, default: ""),
                                    deadline: binding(\.evolveDeadline, default: nil))
            }
            featuredSections
            ChecklistSection(eventID: event.id, suggestions: suggestedTasks)
            remindersSection
            if let link = event.event.link, let url = URL(string: link) {
                Section {
                    Link(destination: url) {
                        Label("Event page on LeekDuck.com", systemImage: "safari")
                    }
                } footer: {
                    Text("Event data from ScrapedDuck, with data by LeekDuck.com.")
                }
            }
        }
        .navigationTitle(event.event.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { notificationsDenied = await ReminderScheduler.authorizationStatus() == .denied }
    }

    // MARK: - Sections

    private var timeSection: some View {
        Section {
            Text(event.event.name)
                .font(.title3.weight(.semibold))
            if let heading = event.event.heading {
                Text(heading).foregroundStyle(.secondary)
            }
            if let start = event.start {
                LabeledContent("Starts", value: EventFormat.dateTime(start))
            } else {
                LabeledContent("Starts", value: "Not announced")
            }
            if let end = event.end {
                LabeledContent("Ends", value: EventFormat.dateTime(end))
            }
        } footer: {
            if event.start != nil {
                Text(event.isGlobalTime
                     ? "Global event: it starts at the same moment worldwide. Shown here in your time zone."
                     : "Local-time event: it runs at these clock times in whatever time zone you're in.")
            }
        }
    }

    @ViewBuilder
    private var featuredSections: some View {
        if !extras.bonuses.isEmpty {
            Section {
                ForEach(extras.bonuses, id: \.self) { Label($0, systemImage: "plus.circle") }
            } header: {
                Text("Bonuses")
            } footer: {
                if !extras.bonusDisclaimers.isEmpty {
                    Text(extras.bonusDisclaimers.joined(separator: "\n"))
                }
            }
        }
        if !extras.raidBosses.isEmpty {
            Section("Raid bosses") {
                ForEach(extras.raidBosses, id: \.name) { boss in
                    HStack {
                        Text(boss.name)
                        Spacer()
                        if boss.canBeShiny {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Can be shiny")
                        }
                    }
                }
            }
        }
        if !extras.featured.isEmpty {
            Section {
                ForEach(extras.featured, id: \.self) { name in
                    HStack {
                        Text(name)
                        Spacer()
                        if let pokemon = dataCenter.lookup?.pokemon(named: name) {
                            TypeBadges(types: pokemon.realTypes)
                        }
                    }
                }
            } header: {
                Text("Featured Pokémon")
            } footer: {
                if let bonus = extras.spotlightBonus { Text("Bonus: \(bonus)") }
            }
        }
        if !extras.shinies.isEmpty && !event.isCommunityDay {
            Section("Can be shiny") {
                Text(extras.shinies.joined(separator: ", "))
            }
        }
        if !extras.specialResearch.isEmpty {
            Section("Special research") {
                ForEach(extras.specialResearch, id: \.self) { step in
                    DisclosureGroup(step.name) {
                        ForEach(Array(step.tasks.enumerated()), id: \.offset) { _, task in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.task)
                                if !task.reward.isEmpty {
                                    Text("Reward: \(task.reward)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !step.rewards.isEmpty {
                            Text("Completion: \(step.rewards.joined(separator: ", "))")
                                .font(.footnote)
                        }
                    }
                }
            }
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Before it starts", isOn: reminderBinding(\.remindBeforeStart))
                .disabled(event.start == nil || event.status != .upcoming)
            Toggle("Before the evolve deadline", isOn: reminderBinding(\.remindBeforeDeadline))
                .disabled(plan?.evolveDeadline == nil)
            Picker("How long before", selection: binding(\.reminderLeadMinutes, default: 60)) {
                ForEach(ReminderScheduler.leadChoices, id: \.self) { minutes in
                    Text(ReminderScheduler.leadText(minutes)).tag(minutes)
                }
            }
            if notificationsDenied {
                Button("Notifications are off for this app. Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text(plan?.evolveDeadline == nil && event.isCommunityDay
                 ? "Set the evolve deadline above to enable that reminder. Reminders are local to this iPhone."
                 : "Reminders are local notifications on this iPhone.")
        }
        .onChange(of: plan?.reminderLeadMinutes) { _, _ in resync() }
    }

    // MARK: - Plan helpers

    private var suggestedTasks: [String] {
        var tasks: [String] = []
        for name in extras.spawns { tasks.append("Catch \(name)") }
        if event.isCommunityDay, let lookup = dataCenter.lookup {
            for name in extras.spawns {
                guard let start = lookup.pokemon(named: name) else { continue }
                let finals = lookup.evolutionLine(from: start).filter { ($0.family?.evolutions ?? []).isEmpty }
                for final in finals where final.speciesId != start.speciesId {
                    tasks.append("Evolve to \(final.speciesName) before the deadline")
                }
            }
        }
        for step in extras.specialResearch { tasks.append("Complete \(step.name)") }
        for boss in extras.raidBosses { tasks.append("Raid: \(boss.name)") }
        return tasks
    }

    /// Returns the plan for this event, creating it on first use.
    private func ensurePlan() -> EventPlan {
        if let plan { return plan }
        let created = EventPlan(eventID: event.id, eventName: event.event.name)
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<EventPlan, T>, default value: T) -> Binding<T> {
        Binding(
            get: { plan?[keyPath: keyPath] ?? value },
            set: { newValue in
                ensurePlan()[keyPath: keyPath] = newValue
                try? modelContext.save()
                resync()
            }
        )
    }

    /// Like `binding`, but asks for notification permission when switched on.
    private func reminderBinding(_ keyPath: ReferenceWritableKeyPath<EventPlan, Bool>) -> Binding<Bool> {
        Binding(
            get: { plan?[keyPath: keyPath] ?? false },
            set: { on in
                ensurePlan()[keyPath: keyPath] = on
                try? modelContext.save()
                Task {
                    if on {
                        let allowed = await ReminderScheduler.requestAuthorization()
                        notificationsDenied = !allowed
                    }
                    await ReminderScheduler.sync(context: modelContext, events: EventCalendar.resolve(dataCenter.events))
                }
            }
        )
    }

    private func resync() {
        Task {
            await ReminderScheduler.sync(context: modelContext, events: EventCalendar.resolve(dataCenter.events))
        }
    }
}
