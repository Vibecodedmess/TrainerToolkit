import SwiftUI

enum AppTab: Hashable {
    case home, search, rocket, events, more
}

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
            // Rocket is a tab (the user's choice, 2026-11-13); Raids is under More.
            NavigationStack { RocketView() }
                .tabItem { Label("Rocket", systemImage: "flag.2.crossed") }
                .tag(AppTab.rocket)
            EventsView()
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag(AppTab.events)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppTab.more)
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
        .environment(DataCenter())
}
