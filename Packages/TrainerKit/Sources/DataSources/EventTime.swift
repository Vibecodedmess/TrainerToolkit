import Foundation

/// An event start or end time as published by ScrapedDuck.
///
/// Per the ScrapedDuck wiki ("Note for Start/End dates"): strings ending in "Z" are the
/// same moment worldwide (UTC). Strings without a zone are wall-clock times that apply in
/// each trainer's own local time zone (for example "10:00 local time everywhere").
public enum EventTime: Equatable, Sendable {
    /// Wall-clock time in the trainer's own time zone.
    case local(DateComponents)
    /// One instant, worldwide.
    case global(Date)

    public init?(isoString raw: String) {
        let string = raw.trimmingCharacters(in: .whitespaces)
        if string.hasSuffix("Z") {
            guard let date = EventTime.parseUTC(string) else { return nil }
            self = .global(date)
        } else {
            guard let components = EventTime.parseLocal(string) else { return nil }
            self = .local(components)
        }
    }

    public var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    /// The actual instant for a trainer in `timeZone` (normally `.current`).
    public func date(in timeZone: TimeZone = .current) -> Date? {
        switch self {
        case .global(let date):
            return date
        case .local(let components):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(from: components)
        }
    }

    private static func parseUTC(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    /// Parses "yyyy-MM-ddTHH:mm[:ss[.SSS]]" without a zone.
    private static func parseLocal(_ string: String) -> DateComponents? {
        let halves = string.split(separator: "T", omittingEmptySubsequences: false)
        guard halves.count == 2 else { return nil }
        let dateParts = halves[0].split(separator: "-").compactMap { Int($0) }
        guard dateParts.count == 3 else { return nil }
        let timeParts = halves[1].split(separator: ":")
        guard timeParts.count >= 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else { return nil }
        var second = 0
        if timeParts.count >= 3 {
            let wholeSeconds = timeParts[2].split(separator: ".").first ?? ""
            guard let parsed = Int(wholeSeconds) else { return nil }
            second = parsed
        }
        guard (1...12).contains(dateParts[1]), (1...31).contains(dateParts[2]),
              (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second) else { return nil }
        return DateComponents(year: dateParts[0], month: dateParts[1], day: dateParts[2],
                              hour: hour, minute: minute, second: second)
    }
}
