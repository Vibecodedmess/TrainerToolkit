import SwiftUI
import DataSources
import GameMath

/// Everything the Home screen shows, worked out once a minute and shared by every look.
struct HomeSnapshot {
    let now: Date
    let events: [ResolvedEvent]
    /// False while the event feed hasn't loaded at all.
    let eventsLoaded: Bool
    let communityDay: ResolvedEvent?
    /// Live events in display order (ending soonest first).
    let live: [ResolvedEvent]
    let topTier: String?
    let topBosses: [SDRaidBoss]
    let raidCount: Int
    let goals: [PowerUpGoal]
    let collectionCount: Int
    let lastBackup: Date?

    init(now: Date, feed: [SDEvent], raids: [SDRaidBoss], goals: [PowerUpGoal], collectionCount: Int,
         lastBackup: Date?) {
        self.now = now
        let events = EventCalendar.resolve(feed, now: now)
        self.events = events
        eventsLoaded = !feed.isEmpty
        communityDay = EventCalendar.nextCommunityDay(in: events)
        live = EventCalendar.sortedForDisplay(events.filter { $0.status == .live })
        let top = RaidsView.tiers(raids).first
        topTier = top
        topBosses = top.map { tier in raids.filter { $0.tier == tier } } ?? []
        raidCount = raids.count
        self.goals = goals
        self.collectionCount = collectionCount
        self.lastBackup = lastBackup
    }

    /// No backup, or none from the last 7 days.
    var backupIsStale: Bool {
        guard let lastBackup else { return true }
        return now.timeIntervalSince(lastBackup) > 7 * 24 * 3600
    }

    /// Time left until `date`, in whole minutes split into days, hours and minutes.
    static func timeLeft(until date: Date, now: Date) -> (days: Int, hours: Int, minutes: Int) {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        return (minutes / (24 * 60), (minutes / 60) % 24, minutes % 60)
    }

    /// "in 3 d 4 h 12 min" countdown, minutes resolution (Home refreshes every minute).
    static func countdown(to date: Date, now: Date) -> String {
        let left = timeLeft(until: date, now: now)
        return left.days > 0
            ? "in \(left.days) d \(left.hours) h \(left.minutes) min"
            : "in \(left.hours) h \(left.minutes) min"
    }

    /// "L20 → L30" style text for a goal.
    static func levelRange(_ goal: PowerUpGoal) -> String {
        "L\(PokemonLevel(halfSteps: goal.currentLevelHalfSteps).description) → L\(PokemonLevel(halfSteps: goal.targetLevelHalfSteps).description)"
    }
}

extension View {
    /// A rounded card on the grouped background, used by the newer looks.
    func homeCard(cornerRadius: CGFloat = 16, padding: CGFloat = 12) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A section title with an optional button on the right ("All", "Planner").
struct HomeSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.subheadline)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
