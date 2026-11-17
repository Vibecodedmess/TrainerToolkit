import SwiftUI
import DataSources

/// Colours and font for the terminal looks.
enum TerminalStyle {
    static let green = Color(red: 0.22, green: 1.0, blue: 0.42)
    static let dim = Color(red: 0.6, green: 0.86, blue: 0.68)
    static let host = Color(red: 0.71, green: 1.0, blue: 0.6)
    static let path = Color(red: 0.39, green: 0.89, blue: 0.93)
    static let amber = Color(red: 0.96, green: 0.88, blue: 0.37)

    static func font(_ style: Font.TextStyle = .footnote) -> Font {
        .system(style, design: .monospaced)
    }
}

/// Home in the "Terminal" looks: the same data as command output. Every line that leads somewhere
/// is tappable. With `alien`, it sits on a dark panel over the moving alien scene.
struct TerminalHome: View {
    let home: HomeSnapshot
    let open: (HomeView.Destination) -> Void
    let scan: () -> Void
    /// Over the moving alien scene instead of plain black.
    var alien = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var host: String { alien ? "trainer@ufo" : "trainer@toolkit" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                summary
                blank
                events
                blank
                raids
                goals
                scanLines
                blank
                cursorLine
            }
            .font(TerminalStyle.font())
            .foregroundStyle(TerminalStyle.green)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if alien {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.62))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(TerminalStyle.green.opacity(0.35)))
                }
            }
            .padding(alien ? 12 : 0)
        }
        .background {
            if alien {
                AlienBackground(dimmed: true)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Blocks

    private var blank: some View {
        Text(verbatim: " ").accessibilityHidden(true)
    }

    private func prompt(_ command: String) -> some View {
        let user: Text = Text(verbatim: host).foregroundStyle(TerminalStyle.host)
        let path: Text = Text(verbatim: "~").foregroundStyle(TerminalStyle.path)
        let typed: Text = Text(verbatim: command).foregroundStyle(Color.white)
        return (user + Text(verbatim: ":") + path + Text(verbatim: "$ ") + typed)
            .accessibilityLabel(command)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var summary: some View {
        prompt("home")
        communityDayBox.padding(.vertical, 4)
        leaderRow("collection", "\(home.collectionCount)") { open(.collection) }
        leaderRow("goals", "\(home.goals.count)") { open(.planner) }
        leaderRow("raid bosses", "\(home.raidCount)") { open(.raids) }
        leaderRow("backup", backupText, valueColor: home.backupIsStale ? TerminalStyle.amber : .white) { open(.backup) }
    }

    private var backupText: String {
        guard let last = home.lastBackup else { return "never" }
        return last.formatted(.relative(presentation: .named))
    }

    @ViewBuilder
    private var communityDayBox: some View {
        if let cd = home.communityDay {
            NavigationLink {
                EventDetailView(event: cd)
            } label: {
                box {
                    Text(verbatim: alien ? "incoming signal: community day" : "community day")
                        .foregroundStyle(TerminalStyle.dim)
                    if cd.status == .live {
                        Text(verbatim: "LIVE NOW").foregroundStyle(Color.white)
                    } else if let start = cd.start {
                        let left = HomeSnapshot.timeLeft(until: start, now: home.now)
                        Text(verbatim: "T-minus \(left.days)d \(Self.pad(left.hours))h \(Self.pad(left.minutes))m")
                            .foregroundStyle(Color.white)
                            .accessibilityLabel(HomeSnapshot.countdown(to: start, now: home.now))
                        Text(start, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                            .foregroundStyle(TerminalStyle.dim)
                    }
                    Text(verbatim: cd.event.name)
                        .foregroundStyle(TerminalStyle.dim)
                        .lineLimit(2)
                }
            }
            .buttonStyle(TerminalRowStyle())
        } else {
            box {
                Text(verbatim: "community day")
                    .foregroundStyle(TerminalStyle.dim)
                Text(verbatim: home.eventsLoaded ? "none announced yet" : "waiting for data...")
            }
        }
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2, content: content)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().strokeBorder(TerminalStyle.green.opacity(0.7),
                                              style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(Rectangle())
    }

    /// "label ........ value", tappable.
    private func leaderRow(_ label: String, _ value: String, valueColor: Color = .white,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: label)
                DottedLeader()
                Text(verbatim: value).foregroundStyle(valueColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TerminalRowStyle())
        .accessibilityLabel("\(label), \(value)")
    }

    @ViewBuilder
    private var events: some View {
        prompt("events --live")
        if home.live.isEmpty {
            Text(verbatim: home.eventsLoaded ? "no events running right now" : "waiting for data...")
                .foregroundStyle(TerminalStyle.dim)
        } else {
            ForEach(home.live.prefix(5)) { event in
                NavigationLink {
                    EventDetailView(event: event)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: "*")
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: event.event.name).foregroundStyle(Color.white).lineLimit(2)
                            if let end = event.end {
                                Text("ends \(end, format: .relative(presentation: .named))")
                                    .foregroundStyle(TerminalStyle.dim)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TerminalRowStyle())
            }
            if home.live.count > 5 {
                Text(verbatim: "... \(home.live.count - 5) more in the Events tab").foregroundStyle(TerminalStyle.dim)
            }
        }
    }

    @ViewBuilder
    private var raids: some View {
        if let tier = home.topTier {
            prompt("raids --top")
            Text(verbatim: "# \(tier)").foregroundStyle(TerminalStyle.dim)
            ForEach(Array(home.topBosses.prefix(6).enumerated()), id: \.offset) { index, boss in
                let types = (boss.types ?? []).map { $0.name.lowercased() }
                let marker: String = index == 0 ? " > " : "   "
                let typeList: String = types.isEmpty ? "" : "  [\(types.joined(separator: "/"))]"
                let name: Text = Text(verbatim: boss.name).foregroundStyle(Color.white)
                let suffix: Text = Text(verbatim: typeList).foregroundStyle(TerminalStyle.dim)
                NavigationLink {
                    RaidBossDetailView(boss: boss)
                } label: {
                    (Text(verbatim: marker) + name + suffix)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TerminalRowStyle())
            }
            Button {
                open(.raids)
            } label: {
                Text(verbatim: "   raids --all (\(home.raidCount) bosses)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TerminalRowStyle())
            blank
        }
    }

    @ViewBuilder
    private var goals: some View {
        if !home.goals.isEmpty {
            prompt("goals")
            ForEach(Array(home.goals.prefix(3).enumerated()), id: \.offset) { _, goal in
                Button {
                    open(.planner)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(verbatim: goal.speciesName).foregroundStyle(Color.white)
                        DottedLeader()
                        Text(verbatim: HomeSnapshot.levelRange(goal)).foregroundStyle(TerminalStyle.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(TerminalRowStyle())
            }
            blank
        }
    }

    @ViewBuilder
    private var scanLines: some View {
        prompt("recommend")
        Button {
            open(.recommended)
        } label: {
            Text(verbatim: " > power-ups, events, raids for you")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(TerminalRowStyle())
        .accessibilityLabel("Recommended for you")
        blank
        prompt("scan")
        Button(action: scan) {
            Text(verbatim: "[ add from screenshots ]")
                .foregroundStyle(Color.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(TerminalStyle.green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to collection from screenshots")
    }

    private var cursorLine: some View {
        HStack(spacing: 0) {
            Text(verbatim: host).foregroundStyle(TerminalStyle.host)
            Text(verbatim: ":")
            Text(verbatim: "~").foregroundStyle(TerminalStyle.path)
            Text(verbatim: "$ ")
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let on = reduceMotion || Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                Rectangle()
                    .fill(TerminalStyle.green)
                    .frame(width: 8, height: 15)
                    .opacity(on ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// A dotted line that fills the space between a label and its value.
private struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 5]))
            .frame(height: 1.5)
            .opacity(0.6)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Terminal lines light up green while pressed.
private struct TerminalRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(TerminalStyle.green.opacity(configuration.isPressed ? 0.22 : 0))
    }
}

/// The terminal looks' tab bar: "[1]home [2]srch ...", the selected tab inverted.
struct TerminalTabBar: View {
    @Binding var selection: AppTab
    /// See-through, for the alien scene.
    var translucent = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    Text(verbatim: "[\(index + 1)]\(Self.shortName(tab))")
                        .font(TerminalStyle.font(.caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(active ? Color.black : TerminalStyle.green)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 7)
                        .background(active ? TerminalStyle.green : Color.clear)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(translucent ? 0.85 : 1))
        .overlay(alignment: .top) {
            Rectangle().fill(TerminalStyle.green.opacity(0.3)).frame(height: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private static func shortName(_ tab: AppTab) -> String {
        switch tab {
        case .home: "home"
        case .search: "srch"
        case .rocket: "rckt"
        case .events: "evts"
        case .more: "more"
        }
    }
}
