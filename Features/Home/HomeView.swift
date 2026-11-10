import SwiftUI

struct HomeView: View {
    @Environment(DataCenter.self) private var dataCenter

    var body: some View {
        NavigationStack {
            PlaceholderView(
                title: "Today at a glance",
                systemImage: "house",
                message: "Active events, current raid bosses, the next Community Day countdown and your planner goals will show here."
            )
            .safeAreaInset(edge: .top) {
                if let warning = dataCenter.warning {
                    WarningBanner(text: warning)
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
        .environment(DataCenter())
}
