import SwiftUI

struct CollectionView: View {
    var body: some View {
        PlaceholderView(
            title: "My Collection",
            systemImage: "square.stack.3d.up",
            message: "Your Pokémon, entered by hand or imported from CSV, used for counter suggestions."
        )
        .navigationTitle("Collection")
    }
}

#Preview {
    NavigationStack { CollectionView() }
}
