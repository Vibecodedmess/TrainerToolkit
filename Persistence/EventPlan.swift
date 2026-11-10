import Foundation
import SwiftData

/// The trainer's own notes and reminder settings for one event (keyed by ScrapedDuck's eventID).
@Model
final class EventPlan {
    @Attribute(.unique) var eventID: String
    var eventName: String
    /// Community Day move, typed in from the official announcement (not in the data feed).
    var exclusiveMove: String
    /// Last moment to evolve for the exclusive move, set by the trainer (not in the data feed).
    var evolveDeadline: Date?
    var remindBeforeStart: Bool
    var remindBeforeDeadline: Bool
    var reminderLeadMinutes: Int

    init(eventID: String, eventName: String) {
        self.eventID = eventID
        self.eventName = eventName
        exclusiveMove = ""
        evolveDeadline = nil
        remindBeforeStart = false
        remindBeforeDeadline = false
        reminderLeadMinutes = 60
    }
}

/// One task on an event's personal checklist.
@Model
final class ChecklistItem {
    var eventID: String
    var text: String
    var isDone: Bool
    var order: Int
    var createdAt: Date

    init(eventID: String, text: String, order: Int) {
        self.eventID = eventID
        self.text = text
        self.isDone = false
        self.order = order
        self.createdAt = .now
    }
}
