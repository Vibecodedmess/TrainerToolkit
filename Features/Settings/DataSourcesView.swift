import SwiftUI

struct DataSourcesView: View {
    var body: some View {
        PlaceholderView(
            title: "Data sources",
            systemImage: "tray.full",
            message: "Each source, its last update time and a Refresh now button will show here."
        )
        .navigationTitle("Data sources")
    }
}

#Preview {
    NavigationStack { DataSourcesView() }
}
