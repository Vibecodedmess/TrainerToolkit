import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                title: "Search String Builder",
                systemImage: "magnifyingglass",
                message: "Build in-game search strings with toggles, preview them live and copy with one tap."
            )
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
