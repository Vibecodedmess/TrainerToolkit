import WidgetKit
import SwiftUI
import DataSources

// The Home Screen widget (Phase 23): the next Community Day and the current top raid tier.
//
// It downloads the public ScrapedDuck event and raid feeds itself, into its own cache, with the same
// rules as the app (bundled snapshot first, at most every 6 hours, ETags, minimum interval per
// source). It can't read the app's data: that would need an App Group, which a free Apple ID can't
// provide through Sideloadly. Text only, no artwork.

@main
struct TrainerToolkitWidgets: WidgetBundle {
    var body: some Widget {
        TrainerWidget()
    }
}

struct TrainerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TrainerWidget", provider: Provider()) { entry in
            TrainerWidgetView(entry: entry)
        }
        .configurationDisplayName("Trainer Toolkit")
        .description("The next Community Day and the current top raid bosses.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
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

    let date: Date
    let communityDay: CommunityDay?
    let liveEvents: Int
    let raidTier: String?
    let bosses: [Boss]
    /// False when neither feed could be read at all.
    let hasData: Bool

    /// Shown while the widget gallery or Home Screen is loading (WidgetKit greys the text out).
    static let placeholder = WidgetEntry(
        date: .now,
        communityDay: CommunityDay(name: "Community Day", start: .now.addingTimeInterval(2 * 24 * 3600), end: nil, isLive: false),
        liveEvents: 2, raidTier: "Raids",
        bosses: [Boss(name: "Raid boss", types: ["type"], canBeShiny: false),
                 Boss(name: "Another boss", types: ["type"], canBeShiny: false)],
        hasData: true)
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

    static func entry(refresh: Bool, now: Date = .now) async -> WidgetEntry {
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
        return WidgetEntry(date: now, communityDay: cd, liveEvents: events.filter { $0.status == .live }.count,
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
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await WidgetData.entry(refresh: false)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let entry = await WidgetData.entry(refresh: true)
            completion(Timeline(entries: [entry], policy: .after(WidgetData.nextUpdate(after: entry))))
        }
    }
}

// MARK: - Views

/// The app's indigo accent (the widget has no asset catalog of its own).
private let accent = Color(red: 0.345, green: 0.337, blue: 0.839)

struct TrainerWidgetView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular {
                Color.clear
            } else {
                LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
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
                .foregroundStyle(accent)
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
    WidgetEntry.placeholder
}
