import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                title: "Today at a glance",
                systemImage: "house",
                message: "Active events, current raid bosses, the next Community Day countdown and your planner goals will show here."
            )
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
