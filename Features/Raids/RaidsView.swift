import SwiftUI

struct RaidsView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                title: "Raid Counter Picker",
                systemImage: "shield.lefthalf.filled",
                message: "Current raid bosses, their weaknesses and your best counters will show here."
            )
            .navigationTitle("Raids")
        }
    }
}

#Preview {
    RaidsView()
}
