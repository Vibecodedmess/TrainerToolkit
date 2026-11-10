import Foundation
import SwiftData
import UserNotifications
import DataSources

/// Local (on-device) reminders for event starts and evolve deadlines. No push, no server.
/// All app reminders use ids starting with "event." and are rebuilt from `EventPlan`s on every sync,
/// so changed event times or settings never leave stale notifications behind.
enum ReminderScheduler {
    static let idPrefix = "event."
    static let leadChoices = [15, 60, 24 * 60]

    struct Planned: Equatable {
        let id: String
        let title: String
        let body: String
        let fireDate: Date
    }

    static func leadText(_ minutes: Int) -> String {
        switch minutes {
        case ..<60: return "\(minutes) minutes"
        case 60: return "1 hour"
        case 24 * 60: return "1 day"
        default: return minutes % 60 == 0 ? "\(minutes / 60) hours" : "\(minutes) minutes"
        }
    }

    /// The reminders that should exist right now.
    static func planned(plans: [EventPlan], events: [ResolvedEvent], now: Date = .now) -> [Planned] {
        var result: [Planned] = []
        for plan in plans {
            guard let event = events.first(where: { $0.id == plan.eventID }) else { continue }
            let lead = TimeInterval(plan.reminderLeadMinutes * 60)
            let name = event.event.name
            if plan.remindBeforeStart, let start = event.start {
                let fire = start.addingTimeInterval(-lead)
                if fire > now {
                    result.append(Planned(
                        id: "\(idPrefix)\(plan.eventID).start",
                        title: name,
                        body: "Starts in \(leadText(plan.reminderLeadMinutes)), at \(start.formatted(date: .omitted, time: .shortened)).",
                        fireDate: fire))
                }
            }
            if plan.remindBeforeDeadline, let deadline = plan.evolveDeadline {
                let fire = deadline.addingTimeInterval(-lead)
                if fire > now {
                    let move = plan.exclusiveMove.isEmpty ? "the exclusive move" : plan.exclusiveMove
                    result.append(Planned(
                        id: "\(idPrefix)\(plan.eventID).deadline",
                        title: "Evolve deadline: \(name)",
                        body: "Evolve for \(move) within \(leadText(plan.reminderLeadMinutes)) (by \(deadline.formatted(date: .omitted, time: .shortened))).",
                        fireDate: fire))
                }
            }
        }
        return result
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks for permission if not decided yet. Returns true if reminders can be shown.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// Replaces all app reminders with the ones the current plans ask for.
    @MainActor
    static func sync(context: ModelContext, events: [ResolvedEvent]) async {
        let plans = (try? context.fetch(FetchDescriptor<EventPlan>())) ?? []
        let wanted = planned(plans: plans, events: events)
        let center = UNUserNotificationCenter.current()

        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard !wanted.isEmpty else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        for reminder in wanted {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
