import Foundation

/// An event with its start/end turned into real instants for the trainer's time zone.
public struct ResolvedEvent: Identifiable, Sendable, Hashable {
    public enum Status: Sendable, Hashable {
        case upcoming, live, ended
        /// No start date published yet.
        case undated
    }

    public let event: SDEvent
    public let start: Date?
    public let end: Date?
    public let status: Status
    /// True when the feed gives a worldwide (UTC) time rather than local wall-clock time.
    public let isGlobalTime: Bool

    public var id: String { event.eventID }
    public var isCommunityDay: Bool { event.eventType == "community-day" }
}

/// Turns the raw event feed into time-zone-aware, sorted, filterable events.
public enum EventCalendar {
    public static func resolve(_ events: [SDEvent], now: Date = Date(), timeZone: TimeZone = .current) -> [ResolvedEvent] {
        events.map { event in
            let start = event.startTime?.date(in: timeZone)
            let end = event.endTime?.date(in: timeZone)
            let global = event.startTime?.isGlobal ?? event.endTime?.isGlobal ?? false
            return ResolvedEvent(event: event, start: start, end: end,
                                 status: status(start: start, end: end, now: now), isGlobalTime: global)
        }
    }

    public static func status(start: Date?, end: Date?, now: Date) -> ResolvedEvent.Status {
        guard let start else { return .undated }
        if now < start { return .upcoming }
        if let end, now >= end { return .ended }
        return .live
    }

    /// Display order: live (ending soonest first), upcoming (starting soonest first),
    /// undated (by name), ended (most recently ended first).
    public static func sortedForDisplay(_ events: [ResolvedEvent]) -> [ResolvedEvent] {
        func rank(_ s: ResolvedEvent.Status) -> Int {
            switch s {
            case .live: return 0
            case .upcoming: return 1
            case .undated: return 2
            case .ended: return 3
            }
        }
        return events.sorted { a, b in
            if rank(a.status) != rank(b.status) { return rank(a.status) < rank(b.status) }
            switch a.status {
            case .live:
                return (a.end ?? .distantFuture, a.event.name) < (b.end ?? .distantFuture, b.event.name)
            case .upcoming:
                return (a.start ?? .distantFuture, a.event.name) < (b.start ?? .distantFuture, b.event.name)
            case .undated:
                return a.event.name < b.event.name
            case .ended:
                return (a.end ?? .distantPast) > (b.end ?? .distantPast)
            }
        }
    }

    /// The Community Day that is live now, or else the next upcoming one.
    public static func nextCommunityDay(in events: [ResolvedEvent]) -> ResolvedEvent? {
        sortedForDisplay(events).first { $0.isCommunityDay && ($0.status == .live || $0.status == .upcoming) }
    }
}
