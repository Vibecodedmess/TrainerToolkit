import SwiftUI

struct TradesView: View {
    var body: some View {
        PlaceholderView(
            title: "Trade Planner",
            systemImage: "arrow.left.arrow.right",
            message: "Friends, want lists and stardust cost per trade."
        )
        .navigationTitle("Trades")
    }
}

#Preview {
    NavigationStack { TradesView() }
}
