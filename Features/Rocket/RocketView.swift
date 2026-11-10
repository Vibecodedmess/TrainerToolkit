import SwiftUI

struct RocketView: View {
    var body: some View {
        PlaceholderView(
            title: "Team Rocket Counters",
            systemImage: "flag.2.crossed",
            message: "Leader, Giovanni and grunt lineups with recommended counters. Works offline."
        )
        .navigationTitle("Rocket")
    }
}

#Preview {
    NavigationStack { RocketView() }
}
