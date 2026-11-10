import SwiftUI

struct EventsView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                title: "Event Checklist",
                systemImage: "calendar",
                message: "Current and upcoming events in your time zone, with a personal checklist per event."
            )
            .navigationTitle("Events")
        }
    }
}

#Preview {
    EventsView()
}
