import SwiftUI

/// Temporary screen content for features that are not built yet.
/// Uses system styles only, so it follows Dark Mode and Dynamic Type.
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

#Preview {
    PlaceholderView(title: "Coming soon", systemImage: "hammer", message: "This screen is a placeholder.")
}
