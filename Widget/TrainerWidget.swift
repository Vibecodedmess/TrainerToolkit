import WidgetKit
import SwiftUI
import AppIntents
import DataSources

// The Home Screen widget (Phases 23–24): the next Community Day and the current top raid tier, in
// the style picked in the widget's own settings (Standard, Alien signal, Terminal).
//
// It downloads the public ScrapedDuck event and raid feeds itself, into its own cache, with the same
// rules as the app (bundled snapshot first, at most every 6 hours, ETags, minimum interval per
// source). It can't read the app's data or look: that would need an App Group, which a free Apple ID
// can't provide through Sideloadly. Text and drawn shapes only, no artwork.

@main
struct TrainerToolkitWidgets: WidgetBundle {
    var body: some Widget {
        TrainerWidget()
    }
}

struct TrainerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TrainerWidget", intent: WidgetStyleIntent.self, provider: Provider()) { entry in
            TrainerWidgetView(entry: entry)
        }
        .configurationDisplayName("Trainer Toolkit")
        .description("The next Community Day and the current top raid bosses. Touch and hold it to pick a style.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Style setting

enum WidgetStyle: String, AppEnum {
    case standard, alien, terminal, alienTerminal

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static var caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] = [
        .standard: "Standard",
        .alien: "Alien signal",
        .terminal: "Terminal",
        .alienTerminal: "Terminal, alien edition",
    ]

    /// Styles over the moving alien scene, which get one pose per minute.
    var isAlien: Bool { self == .alien || self == .alienTerminal }
}

struct WidgetStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget style"
    static var description = IntentDescription("Pick how the widget looks.")

    @Parameter(title: "Style", default: .standard)
    var style: WidgetStyle
}

// MARK: - Data

struct WidgetEntry: TimelineEntry {
    struct CommunityDay {
        let name: String
        let start: Date?
        let end: Date?
        let isLive: Bool
    }

    struct Boss: Identifiable {
        let name: String
        let types: [String]
        let canBeShiny: Bool
        var id: String { name }
    }

    var date: Date
    var style: WidgetStyle
    let communityDay: CommunityDay?
    let liveEvents: Int
    let raidTier: String?
    let bosses: [Boss]
    /// False when neither feed could be read at all.
    let hasData: Bool

    /// The same data at another moment (the alien scene's next pose).
    func at(_ date: Date) -> WidgetEntry {
        var copy = self
        copy.date = date
        return copy
    }

    /// Shown while the widget gallery or Home Screen is loading (WidgetKit greys the text out).
    static func placeholder(style: WidgetStyle = .standard) -> WidgetEntry {
        WidgetEntry(
            date: .now, style: style,
            communityDay: CommunityDay(name: "Community Day", start: .now.addingTimeInterval(2 * 24 * 3600), end: nil, isLive: false),
            liveEvents: 2, raidTier: "Raids",
            bosses: [Boss(name: "Raid boss", types: ["type"], canBeShiny: false),
                     Boss(name: "Another boss", types: ["type"], canBeShiny: false)],
            hasData: true)
    }
}

enum WidgetData {
    /// The widget's own cache, separate from the app's.
    static let store: DataStore = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return DataStore(cacheDirectory: base.appendingPathComponent("WidgetDataCache", isDirectory: true),
                         sources: [.events, .raids])
    }()

    /// Same default as the app's "Check for new data" setting.
    static let refreshInterval: TimeInterval = 6 * 3600

    static func entry(refresh: Bool, style: WidgetStyle, now: Date = .now) async -> WidgetEntry {
        if refresh { _ = await store.refreshIfStale(maxAge: refreshInterval) }
        let feed = await store.decoded(LossyArray<SDEvent>.self, for: .events)?.elements
        let raids = await store.decoded(LossyArray<SDRaidBoss>.self, for: .raids)?.elements

        let events = EventCalendar.resolve(feed ?? [], now: now)
        let cd = EventCalendar.nextCommunityDay(in: events).map {
            WidgetEntry.CommunityDay(name: $0.event.name, start: $0.start, end: $0.end, isLive: $0.status == .live)
        }
        let tier = SDRaidBoss.tiersInDisplayOrder(raids ?? []).first
        let bosses = (raids ?? []).filter { $0.tier == tier }.map {
            WidgetEntry.Boss(name: $0.name, types: ($0.types ?? []).map(\.name), canBeShiny: $0.canBeShiny == true)
        }
        return WidgetEntry(date: now, style: style, communityDay: cd,
                           liveEvents: events.filter { $0.status == .live }.count,
                           raidTier: tier, bosses: bosses, hasData: feed != nil || raids != nil)
    }

    /// When to build the next timeline: when the Community Day starts or ends, or after the refresh
    /// interval, whichever comes first (WidgetKit may wait longer to save battery).
    static func nextUpdate(after entry: WidgetEntry) -> Date {
        var next = entry.date.addingTimeInterval(refreshInterval)
        if let cd = entry.communityDay {
            for moment in [cd.start, cd.end].compactMap({ $0 }) where moment > entry.date && moment < next {
                next = moment
            }
        }
        return next
    }

    /// How long one prepared alien timeline lasts: one pose per minute.
    static let alienSteps = 60
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { .placeholder() }

    func snapshot(for configuration: WidgetStyleIntent, in context: Context) async -> WidgetEntry {
        if context.isPreview { return .placeholder(style: configuration.style) }
        return await WidgetData.entry(refresh: false, style: configuration.style)
    }

    func timeline(for configuration: WidgetStyleIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let entry = await WidgetData.entry(refresh: true, style: configuration.style)
        let next = WidgetData.nextUpdate(after: entry)
        guard configuration.style.isAlien, context.family != .accessoryRectangular else {
            return Timeline(entries: [entry], policy: .after(next))
        }
        // Widgets can't animate continuously: iOS shows prepared entries and animates the change
        // between them. One pose per minute for the next hour, then a new timeline (data is only
        // downloaded when it's older than the refresh interval).
        let start = entry.date
        var entries: [WidgetEntry] = []
        for step in 0..<WidgetData.alienSteps {
            let date = start.addingTimeInterval(Double(step) * 60)
            guard date < next else { break }
            entries.append(entry.at(date))
        }
        let end = min(next, start.addingTimeInterval(Double(WidgetData.alienSteps) * 60))
        return Timeline(entries: entries, policy: .after(end))
    }
}

// MARK: - Views

/// The app's indigo accent (the widget has no asset catalog of its own).
let widgetAccent = Color(red: 0.345, green: 0.337, blue: 0.839)

struct TrainerWidgetView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            lockScreen
                .containerBackground(for: .widget) { Color.clear }
        } else {
            switch entry.style {
            case .standard:
                standard
                    .containerBackground(for: .widget) {
                        LinearGradient(colors: [widgetAccent.opacity(0.22), widgetAccent.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
            case .alien:
                AlienWidgetContent(entry: entry, family: family)
                    .containerBackground(for: .widget) { AlienWidgetScene(date: entry.date) }
            case .terminal:
                TerminalWidgetContent(entry: entry, family: family)
                    .containerBackground(for: .widget) { Color.black }
            case .alienTerminal:
                TerminalWidgetContent(entry: entry, family: family, onAlienScene: true)
                    .containerBackground(for: .widget) { AlienWidgetScene(date: entry.date, dimmed: true) }
            }
        }
    }

    @ViewBuilder
    private var standard: some View {
        if family == .systemMedium { medium } else { small }
    }

    // MARK: Community Day

    @ViewBuilder
    private var countdown: some View {
        if let cd = entry.communityDay {
            if cd.isLive {
                Text("Live now").font(.title3.weight(.bold)).foregroundStyle(.green)
                if let end = cd.end {
                    (Text("ends in ") + Text(end, style: .relative))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let start = cd.start {
                Text(start, style: .relative)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(start, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(entry.hasData ? "None announced yet" : "No data yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var communityDayBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Community Day", systemImage: "calendar.badge.clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(widgetAccent)
                .lineLimit(1)
            if let cd = entry.communityDay {
                Text(cd.name)
                    .font(.caption)
                    .lineLimit(2)
            }
            Spacer(minLength: 2)
            countdown
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            communityDayBlock
            if entry.liveEvents > 0 {
                Label(entry.liveEvents == 1 ? "1 event live" : "\(entry.liveEvents) events live",
                      systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            communityDayBlock
            VStack(alignment: .leading, spacing: 4) {
                Label(entry.raidTier ?? "Raids", systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                if entry.bosses.isEmpty {
                    Text("No raid bosses yet").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(entry.bosses.prefix(4)) { boss in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 3) {
                                Text(boss.name).font(.caption.weight(.semibold)).lineLimit(1)
                                if boss.canBeShiny {
                                    Image(systemName: "sparkles").font(.caption2).foregroundStyle(.yellow)
                                        .accessibilityLabel("Can be shiny")
                                }
                            }
                            if !boss.types.isEmpty {
                                Text(boss.types.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    if entry.bosses.count > 4 {
                        Text("+ \(entry.bosses.count - 4) more").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Community Day").font(.headline).widgetAccentable()
            if let cd = entry.communityDay {
                if cd.isLive {
                    Text("Live now")
                } else if let start = cd.start {
                    (Text("in ") + Text(start, style: .relative))
                }
            } else {
                Text(entry.hasData ? "None announced yet" : "No data yet")
            }
            if let boss = entry.bosses.first {
                Text("Raid: \(boss.name)").foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemMedium) {
    TrainerWidget()
} timeline: {
    WidgetEntry.placeholder()
    WidgetEntry.placeholder(style: .alien)
    WidgetEntry.placeholder(style: .terminal)
    WidgetEntry.placeholder(style: .alienTerminal)
}
