import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home, search, rocket, events, more

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .rocket: "Rocket"
        case .events: "Events"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .rocket: "flag.2.crossed"
        case .events: "calendar"
        case .more: "ellipsis.circle"
        }
    }

    /// The tab's screen.
    @MainActor @ViewBuilder
    var root: some View {
        switch self {
        case .home: HomeView()
        case .search: SearchView()
        // Rocket is a tab (the user's choice, 2026-11-13); Raids is under More.
        case .rocket: NavigationStack { RocketView() }
        case .events: EventsView()
        case .more: MoreView()
        }
    }
}

struct RootTabView: View {
    @State private var selection: AppTab = .home
    @AppStorage(AppLook.storageKey) private var look: AppLook = .standard

    var body: some View {
        Group {
            switch look {
            case .dock:
                CustomTabView(selection: $selection) { FloatingDock(selection: $selection) }
            case .terminal, .alienTerminal:
                CustomTabView(selection: $selection) {
                    TerminalTabBar(selection: $selection, translucent: look == .alienTerminal)
                }
            case .alien:
                CustomTabView(selection: $selection) { AlienTabBar(selection: $selection) }
            case .standard, .widgets, .timeline:
                TabView(selection: $selection) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tab.root
                            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                            .tag(tab)
                    }
                }
            }
        }
        .tint(look.tint)
        .preferredColorScheme(look.colorScheme)
    }
}

#Preview {
    RootTabView()
        .environment(DataCenter())
}
