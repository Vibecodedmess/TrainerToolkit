import SwiftUI

enum AppTab: Hashable {
    case home, search, raids, events, more
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
            RaidsView()
                .tabItem { Label("Raids", systemImage: "shield.lefthalf.filled") }
                .tag(AppTab.raids)
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
